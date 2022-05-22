-- lipperdam
--  
-- latency compensating sequencer
-- 1.0.0 @dewb
--

engine.name = 'PolyPerc'

running = true

g = grid.connect()

latency = 0.420
step_length = 0
step_delay = 0
ms_delay = 0

function update_offsets()
  step_length = clock.get_beat_sec()/4
  step_delay = 1 + math.floor(latency / step_length)
  ms_delay = step_length - (latency % step_length)
end


tracks = {
  {
    pos = 0,
    length = 16,
    data = {1,0,3,5,6,7,8,7,0,0,0,0,0,0,0,0}
  },
  {
    pos = 0,
    length = 16,
    data = {5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  },
  {
    pos = 0,
    length = 16,
    data = {5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  },
  {
    pos = 0,
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
  one.pos = 1
  two.pos = 1
  three.pos = 1
  four.pos = 1
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

function step()
  while true do
    update_offsets()
    
    clock.sync(1/4)
    if (ms_delay > 0) then
      clock.sleep(ms_delay)
    end
    
    if running then
      engine.hz(tracks[1].pos == 1 and 880 or 220)
      
      for t = 1,4 do
        tracks[t].pos = (tracks[t].pos % tracks[t].length) + 1
        crow.output[t].volts = tracks[t].data
        crow.output[t].execute()
      end
      
    end
    
    if g then
      gridredraw()
    end
    redraw()

  end
end

function init()


  params:add_separator("LIPPERDAM")
  
  params:default()
  

  norns.enc.sens(1,8)
  
  update_offsets()

  
  clock.run(step)
  
end

function g.key(x, y, z)
  gridredraw()
  redraw()
end

function gridredraw()
  g:all(0)
  t = 1
  for y = 1, 8 do
    for x = 1, 16 do
      if tracks[t].data[x] > (8 - y) then 
        if tracks[t].pos == x then
          g:led(x, y, 15)
        else
          g:led(x, y, 5) 
        end
      else
        if tracks[t].pos == x then
          g:led(x, y, 10)
        end
      end
    end
  end
  g:refresh()
end

function enc(n, delta)
  if n==1 then
    latency = math.max(0, latency + delta/1000)
  elseif n == 2 then
  elseif n == 3 then
  end
  redraw()
end

function key(n,z)

  if n == 3 and z == 1 then
    for t=1,4 do
      tracks[t].pos = (step_delay) % 16 + 1
    end
    
  end

  redraw()
end

function redraw()
  screen.clear()
  screen.line_width(1)
  screen.aa(0)

  screen.level(4)
  screen.move(0,10)
  screen.text("latency comp: ".. math.floor(latency * 1000) .. "ms")
  screen.move(0,20)
  screen.text("step length: ".. math.floor(step_length * 1000) .. "ms")
  screen.move(0,30)
  screen.text("step delay: ".. step_delay)
  screen.move(0,40)
  screen.text("ms delay: ".. math.floor(ms_delay * 1000) .. "ms")

  screen.update()
end

function cleanup()
end
