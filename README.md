# warden

divide softcut buffer space into arbitrarily nested recording and/or playback slices.

# usage

### buffers:
- `warden.buffer`: a table of two mono slices for each softcut buffer.
- `warden.buffer_stereo`: the buffers as one stereo slice.

### constructors:
- `warden.divide(input)`: split the input slice into evenly sized slices. returns a table.
- `warden.subloop(input, n)`: create `n` slices clamped to the input slice or slices. returns a slice or a table.

### setters & getters:
- `Slice:set_start(t, <'seconds' or 'fraction'>, <'relative' or 'absolute'>)` 
- `Slice:set_end(t, <'seconds' or 'fraction'>, <'relative' or 'absolute'>)` 
- `Slice:set_length(t, <'seconds' or 'fraction'>)` 
- `Slice:get_start(<'seconds' or 'fraction'>, <'relative' or 'absolute'>)` 
- `Slice:get_end(<'seconds' or 'fraction'>, <'relative' or 'absolute'>)` 
- `Slice:get_length(<'seconds' or 'fraction'>)`

### methods:
- `Slice:update_voice([voice, ])`: send the start point, end point, & buffer(s) of the slice to softcut voice(s).
- `Slice:phase_relative(phase, <'seconds' or 'fraction'>)`: scale phase from `phase_event`
- `Slice:clear()`
- `Slice:copy(source_slice, fade_time, reverse)`
- `Slice:read(file, start_src, ch_src)`
- `Slice:write(file)`: `buffer_write_`
- `Slice:render(samples)`: `render_buffer`

# example
```
--setup buffer regions

--available recording areas, divided evenly across softcut buffer 1
blank_area = warden.divide(warden.buffer[1], 2)

--the actual areas of recorded material, clamped to each  available blank area
rec_area = warden.subloop(blank_area)

--the areas of playback, clamped to each area of recorded material
play_area = warden.subloop(rec_area)

for i = 1, #blank_area do

    --set loop points
    rec_area[i]:set_start(0)
    rec_area[i]:set_end(1)

    play_area[i]:set_start(0.3, 'fraction')
    play_area[i]:set_length(0.2, 'fraction')
    
    --push to voice
    play_area[i]:update_voice(i)
end
```
