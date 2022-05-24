lipperdam
=========

time-traveling latency compensation sequencer

clocked modulation source for live manipulation of high-latency output pipelines  
(from 0ms to 10,000s of ms)

the intended use is enabling improvisational performance in situations where
prerecorded sequencing would normally be required.

possible examples:
- projection mapping systems with many frames of delay
- solenoid-driven flame or percussion effects
- controlling a sound source at the other side of a large chamber
- other physical systems with significant delay between actuation and visible/audible effect

## hardware support

requirements:
- norns

strongly recommended:
- crow or midi output device
- grid

nice to have:
- midi knob or fader controller for params

## todo

- [ ] scale/offset crow output
- [ ] crow max output voltage range
- [ ] ramp mode, lin/exp curves, slew
- [ ] params for crow output assignments
- [ ] pattern bank switching on bar quantum
- [ ] more params
- [ ] save pattern banks to pset
- [ ] different quantum per track
- [ ] different latency per track
- [ ] midi output
- [ ] more ui
- [ ] switch between step/level mode & breakpoint mode
- [ ] params for engine output

