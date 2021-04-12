# warden

divide softcut buffer space into arbitrarily nested recording and/or playback slices.

# usage

### buffers:
- `warden.buffer`: a `bundle` of two mono slices for each softcut buffer.
- `warden.buffer_stereo`: the buffers as one stereo slice.

### constructors:
- `warden.divide(input, n)`: divide the input slice(s) into `n` evenly sized subslices. returns a `bundle` of slices.
- `warden.subloop(input, n)`: create `n` subslices clamped to the input `slice` or `bundle`. returns a `bundle` or a single `slice`.

### voice assignment
- `warden.assign(input, [voice, ])`: assign the input `slice` or `bundle` to the softcut voice(s). two voices may be assigned to one stereo `slice` for stereo use.

### setters & getters:
- `bundle:set_start(voice, t, <'seconds' or 'fraction'>, <'relative' or 'absolute'>)` 
- `bundle:set_end(voice, t, <'seconds' or 'fraction'>, <'relative' or 'absolute'>)` 
- `bundle:set_length(voice, t, <'seconds' or 'fraction'>)` 
- `bundle:get_start(voice, <'seconds' or 'fraction'>, <'relative' or 'absolute'>)` 
- `bundle:get_end(voice, <'seconds' or 'fraction'>, <'relative' or 'absolute'>)` 
- `bundle:get_length(voice, <'seconds' or 'fraction'>)`
- `bundle:delta_start(voice, t, <'seconds' or 'fraction'>, <'relative' or 'absolute'>)` 
- `bundle:delta_end(voice, t, <'seconds' or 'fraction'>, <'relative' or 'absolute'>)` 
- `bundle:delta_length(voice, t, <'seconds' or 'fraction'>)`
- `bundle:get_slice(voice)`: get the slice object stored in the bundle

### methods:
- `bundle:phase_relative(voice, phase, <'seconds' or 'fraction'>)`: scale phase from `phase_event`
- `bundle:position(voice, value, units)`: set position relative to slice
- `bundle:clear(voice)`
- `bundle:copy(voice, source_slice, fade_time, reverse)`
- `bundle:read(voice, file, start_src, ch_src)`
- `bundle:write(voice, file)`
- `bundle:render(voice, samples)`

### state

- `warden.save([input, ], file number, file name)`: save slice tables to disk
- `warden.load([input, ], file number, file name)`: load save file to slice tables

# example
```
--setup buffer regions

--available recording areas, divided evenly across softcut buffer 1
blank_area = warden.divide(warden.buffer[1], 2)

--the actual areas of recorded material, clamped to each  available blank area
rec_area = warden.subloop(blank_area)

--the areas of playback, clamped to each area of recorded material
play_area = warden.subloop(rec_area)

--assign softcut voices to playback slices
warden.assign(play_area[1], 1)
warden.assign(play_area[2], 2)

for i = 1, 2 do
    rec_area:set_start(i, 0)
    rec_area:set_end(i, 1)

    play_area:set_start(i, 0.3, 'fraction')
    play_area:set_length(i, 0.2, 'fraction')
end
```
