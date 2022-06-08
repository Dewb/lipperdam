-- lipperdam
--  
-- time-traveling latency compensation sequencer
-- 1.0.0 @dewb
--

engine.name = 'PolyPerc'

running = false

g = grid.connect()
midi_output = nil

latency = 0.210
step_length = 0
offset_whole_steps = 0
offset_frac_ms = 0
offset_frac_beat = 0

selected_output = 1
selected_output_enc = 1

function update_offsets()
  beat_length = clock.get_beat_sec()
  step_length = beat_length/params:get("step_div")
  offset_whole_steps = latency > 0 and 1 + math.floor(latency / step_length) or 0
  offset_frac_ms = latency > 0 and step_length - (latency % step_length) or 0
  offset_frac_beat = offset_frac_ms/beat_length
end


tracks = {
  {
    output_pos = 0,
    ui_pos = 0,
    length = 16,
    data = {1,0,3,5,6,7,8,7,0,0,0,0,0,0,0,0}
  },
  {
    output_pos = 0,
    ui_pos = 0,
    length = 16,
    data = {5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  },
  {
    output_pos = 0,
    ui_pos = 0,
    length = 16,
    data = {5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  },
  {
    output_pos = 0,
    ui_pos = 0,
    length = 16,
    data = {5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  }
}

midi_notes = {
  { selected = 1, data = {50, 51, 52, 53, 54}},
  { selected = 1, data = {60,61}},
  { selected = 1, data = {70,71,72,73,74,75,76}},
  { selected = 1, data = {80,81,82,83}}
}

function stop()
  running = false
end

function start()
  running = true
end

function reset()
  for t=1,4 do
    tracks[t].ui_pos = 0
    --tracks[t].output_pos = offset_whole_steps % tracks[t].length 
  end
end

function clock.transport.start()
  start()
end

function clock.transport.stop()
  stop()
end

function clock.transport.reset()
  reset()
end

function advance_ui_positions()
  for t = 1,4 do
    tracks[t].ui_pos = (tracks[t].ui_pos % tracks[t].length) + 1
  end
end

function update_output_positions()
  for t = 1,4 do
    tracks[t].output_pos = (tracks[t].ui_pos + offset_whole_steps - 1) % tracks[t].length + 1
  end
end

function step()
  while true do
    update_offsets()
    
    clock.sync(1/params:get("step_div"))
      
    if running then
      advance_ui_positions()
      update_output_positions()
    end
    
    step_ui()
    
    if (offset_frac_beat > 0) then
      --clock.sync(1/params:get("step_div"), offset_frac_beat)
      --clock.sleep(offset_frac_ms)
      clock.sync(1/params:get("step_div"), -(1 - offset_frac_beat))
    end

    step_output()

  end
end

function step_ui()

  if g then
    gridredraw()
  end
  redraw()

end

function step_output()
  if running then

    local scale_param_names = { "scale_1", "scale_2", "scale_3", "scale_4" }
    local offset_param_names = { "offset_1", "offset_2", "offset_3", "offset_4" }

    for t = 1,4 do
      scale = params:get(scale_param_names[t])/100.0
      offset = params:get(offset_param_names[t])
      tracks[t].output_pos = (tracks[t].ui_pos + offset_whole_steps - 1) % tracks[t].length + 1
      crow.output[t].volts = tracks[t].data[tracks[t].output_pos]/8.0 * scale + offset
      --crow.output[t].execute()
    end
  
    if midi_output ~= nil then
      if tracks[1].output_pos == params:get("midi_fire_position") then
        for m = 1, #midi_notes do
          local n = midi_notes[m].data[midi_notes[m].selected]
          if n ~= midi_notes[m].previous_value then
            midi_output:note_off(midi_notes[m].previous_value, 120, 1)
            midi_output:note_on(n, 120, 1)
            midi_notes[m].previous_value = n
          end
        end
      end
    end

    engine.hz(tracks[1].output_pos == 1 and 880 or 220)
  
  end
end

function init()

  params:add_separator("LIPPERDAM")
  
  params:add{type = "number", id = "step_div", name = "step division", min = 1, max = 16, default = 2}
  params:add{type = "number", id = "midi_fire_position", name = "midi event fire position", min = 1, max = 16, default = 1}
  params:add{type = "number", id = "midi_output_device", name = "midi output device", min = 1, max = 4, default = 2, 
    action = function (x)
      midi_output = midi.connect(x)
    end
  }

  local volts_spec = controlspec.def{
    min=0.00,
    max=1.0,
    warp='lin',
    step=0.001,
    default=0.0,
    quantum=0.001,
    wrap=false,
    units='V'
  } 

  local scale_spec = controlspec.def{
    min=0.00,
    max=100.0,
    warp='lin',
    step=0.1,
    default=100.0,
    quantum=0.001,
    wrap=false,
    units='%'
  } 

  params:add_control("scale_1", "scale 1", scale_spec)
  params:add_control("scale_2", "scale 2", scale_spec)
  params:add_control("scale_3", "scale 3", scale_spec)
  params:add_control("scale_4", "scale 4", scale_spec)

  params:add_control("offset_1", "offset 1", volts_spec)
  params:add_control("offset_2", "offset 2", volts_spec)
  params:add_control("offset_3", "offset 3", volts_spec)
  params:add_control("offset_4", "offset 4", volts_spec)

  --norns.enc.sens(1,8)
  crow.init()

  params:default()


  midi_output = midi.connect(params:get("midi_output_device"))

  clock.run(step)
  
end

function g.key(x, y, z)
  if z == 1 and selected_output > 0 then
    local value = 9-y
    if tracks[selected_output].data[x] == value then
      tracks[selected_output].data[x] = 0
    else 
      tracks[selected_output].data[x] = value
    end
  elseif z == 1 and selected_output == 0 then
    local value = x
    if y <= #midi_notes and x <= #(midi_notes[y].data) then
      midi_notes[y].selected = x
    end
  end
  gridredraw()
  redraw()
end

function gridredraw()
  g:all(0)
  t = selected_output
  if t > 0 then
    for y = 1, 8 do
      for x = 1, 16 do
        if tracks[t].data[x] > (8 - y) then 
          if tracks[t].ui_pos == x then
            g:led(x, y, 15)
          else
            g:led(x, y, 5) 
          end
        else
          if tracks[t].ui_pos == x then
            g:led(x, y, 10)
          elseif tracks[t].output_pos == x then
            g:led(x, y, 2)
          end
        end
      end
    end
  elseif t == 0 then
    for y = 1, 8 do
      for x = 1, 16 do
        if tracks[1].ui_pos == x then
          g:led(x, y, 10)
        elseif tracks[1].output_pos == x then
          g:led(x, y, 2)
        end
      end
    end
    for y = 1,#midi_notes do
      for x = 1, #(midi_notes[y].data) do
        g:led(x, y, x == midi_notes[y].selected and 15 or 6)
      end
    end
  end
  g:refresh()
end

function enc(n, delta)
  if n==1 then
    -- change mode
  elseif n == 2 then
    -- change track/output
    selected_output_enc = util.clamp(selected_output_enc + delta/3, 0, 4)
    selected_output = math.floor(selected_output_enc+0.5)
  elseif n == 3 then
    -- change mode main parameter
    latency = math.max(0, latency + delta/1000)
    update_offsets()
    update_output_positions()
  end
  if g then
    gridredraw()
  end
  redraw()
end

function key(n,z)
  if n == 2 and z == 1 then
    if running then
      stop()
    else
      start()
    end
  elseif n == 3 and z == 1 then
    reset()
  end
  redraw()
end

function redraw()
  screen.clear()
  screen.line_width(1)
  screen.aa(0)
  
  screen.level(4)
  screen.rect(0,0,31,10)
  screen.fill()
  screen.level(0)
  screen.move(3,7)
  screen.text("config")
  
  for t=0,4 do
    if t == selected_output then
      screen.level(4)
      screen.rect(76+t*10,0,10,10)
      screen.fill()
      screen.level(0)
      
    else
      screen.level(4)
    end

    if t == 0 then
      screen.move(78,7)
      screen.text("M")
    else
      screen.move(76+t*10+3,7)
      screen.text(t)
    end
  end
  
  if running then
    screen.level(6)
    screen.move(120,16)
    screen.text("▶")
  end

  screen.level(4)
  screen.move(0,30)
  screen.text("latency compensation: ".. math.floor(latency * 1000) .. "ms")
  screen.move(0,46)
  screen.text("step length: ".. math.floor(step_length * 1000) .. "ms")
  screen.move(0,54)
  screen.text("whole step offset: ".. offset_whole_steps)
  screen.move(0,62)
  screen.text("ms offset: ".. math.floor(offset_frac_ms * 1000) .. "ms")
  --screen.text("frac beat offset: ".. offset_frac_beat)

  screen.update()
end

function cleanup()
end
