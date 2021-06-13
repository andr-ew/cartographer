# cartographer

divide softcut buffer space into arbitrarily nested recording and/or playback slices.

### problem:

working with two buffer spaces in vanilla softcut is straighforward, but working with more independent "virtual" buffer spaces involves designing specialized data structures and specialized functions to re-scale that data & modify loop points without spilling into the next adjacent buffer space or unused silence. it all gets far messier once you decide to add a feature to reassign voices to different virtual buffers.

### solution:

cartographer - a data structure utility for creating virtual buffer space objects (`slices`) that can be nested inside of each other. a `slice` may represent the acutal loop points of a softcut voice (when the slice has been assigned to a voice) and/or the outer boundries of another slice's loop points (or boundaries of boundaries). utilities are provided for creating groups of slices (`bundles`), assigning slices to softcut voices, manipulating slice points (in seconds or relative values), and convenience wrappers for working with the softcut buffers. 

# usage

### buffers:
- `cartographer.buffer`: a `bundle` of two mono slices for each softcut buffer.
- `cartographer.buffer_stereo`: the buffers as one stereo slice.

### constructors:
- `cartographer.divide(input, n)`: divide the input slice(s) into `n` evenly sized subslices. returns a `bundle` of slices.
- `cartographer.subloop(input, n)`: create `n` subslices clamped to the input `slice` or `bundle`. returns a `bundle` or a single `slice`.
- `cartographer.folder(input, [path, ], max_length)`: load the folder(s) of samples into the input `slice` or `bundle` and divide based on sample length

### voice assignment:
- `cartographer.assign(input, [voice, ])`: assign the input `slice` or `bundle` to the softcut voice(s). two voices may be assigned to one stereo `slice` for stereo use.

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
- `bundle:delta_startend(voice, t, <'seconds' or 'fraction'>)`: adjusts both start & end with better clamping
- `bundle:get_slice(voice)`: get the slice object stored in the bundle

### methods:
- `bundle:phase_relative(voice, phase, <'seconds' or 'fraction'>)`: scale phase from `phase_event`
- `bundle:position(voice, value, units)`: set position relative to slice
- `bundle:trigger(voice)`: set position to the start of the slice (0)
- `bundle:clear(voice)`
- `bundle:copy(voice, source_slice, fade_time, reverse)`
- `bundle:read(voice, file, start_src, ch_src)`
- `bundle:write(voice, file)`
- `bundle:render(voice, samples)`
- `bundle:punch_in(voice)`
- `bundle:punch_out(voice)`

### state

- `cartographer.save([input, ], file number, file name)`: save bundle(s) to disk
- `cartographer.load([input, ], file number, file name)`: load save file to bundle(s)

# simple example
```
--setup buffer regions

--available recording areas, divided evenly across softcut buffer 1
blank_areas = cartographer.divide(cartographer.buffer[1], 2)

--the actual areas of recorded material, clamped to each  available blank area
rec_areas = cartographer.subloop(blank_areas)

--the areas of playback, clamped to each area of recorded material
play_areas = cartographer.subloop(rec_areas)

--assign softcut voices to playback slices
cartographer.assign(play_areas[1], 1)
cartographer.assign(play_areas[2], 2)

for i = 1, 2 do
    rec_areas:set_start(i, 0)
    rec_areas:set_end(i, 1)

    play_areas:set_start(i, 0.3, 'fraction')
    play_areas:set_length(i, 0.2, 'fraction')
end
```

# demo

[six loop pedals](https://github.com/andr-ew/cartographer_demo)

# including

download this repo to your `lib/` folder or include it as a [submodule](https://github.blog/2016-02-01-working-with-submodules/). then, at the beginning of your script add:
```
cartographer = include 'lib/cartographer/cartographer'
```
