-- lipperdam
--  
-- time-traveling latency compensation sequencer
-- 1.0.0 @dewb
--

engine.name = 'PolyPerc'

running = false

g = grid.connect()

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

    for t = 1,4 do
      tracks[t].output_pos = (tracks[t].ui_pos + offset_whole_steps - 1) % tracks[t].length + 1
      crow.output[t].volts = tracks[t].data
      crow.output[t].execute()
    end
    engine.hz(tracks[1].output_pos == 1 and 880 or 220)
  end
end

function init()

  params:add_separator("LIPPERDAM")
  params:default()
  
  params:add{type = "number", id = "step_div", name = "step division", min = 1, max = 16, default = 4}

  --norns.enc.sens(1,8)

  clock.run(step)
  
end

function g.key(x, y, z)
  if z == 1 then
    tracks[selected_output].data[x] = (9-y)
  end
  gridredraw()
  redraw()
end

function gridredraw()
  g:all(0)
  t = selected_output
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
  g:refresh()
end

function enc(n, delta)
  if n==1 then
    -- change mode
  elseif n == 2 then
    -- change track/output
    selected_output_enc = util.clamp(selected_output_enc + delta/3, 1, 4)
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
  
  for t=1,4 do
    if (t == selected_output) then
      screen.level(4)
      screen.rect(76+t*10,0,10,10)
      screen.fill()
      screen.level(0)
      
    else
      screen.level(4)
    end
    screen.move(76+t*10+3,7)
    screen.text(t)
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
