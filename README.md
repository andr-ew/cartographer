# warden

simplify the division of softcut buffer space into arbitrary recording and/or playback regions

### types

`region`: division, placed end-to-end in buffer space and will not cross another region.

`loop`: may occupy any area within a region, overlap other loops within that region

`warden`: a special case of `region` that occupies the total softcut buffer space

### methods

`:make(type, n)`: initiates `n` of type `region` or `loop` within `warden` or another object created with make. 
  - `region`s are initiated with start & end points that evenly divide all regions across the parent object.
  - `loop`s are initiated with start & end points equal to the parent object

`:s_start(x)`: set the start point in seconds. 0 corresponds to the starting point of the parent object.

`:s_end(x)`: set the end point in seconds. this value is clamped to the length of the parent object.

`:s_len(x)`: set the length in seconds. this value is clamped to the remaining space in the parent object.

`:f_start(x)`: set start point as a fraction of the parent object size.

`:f_end(x)`: set end point as a fraction of the parent object size.

`:f_len(x)`: set the length a fraction of the parent object size. this value is clamped to the remaining space in the parent object.

`:push(n)`: assign the start end & end points of the object to the nth softcut voice

### example usage

```
warden:make(region, 8):make(region, 1):make(loop, 4) -- initiate nested regions regions & loops

-- modify start & end points reative to parent objects

warden.region[1]:start(2)
warden.region[1]:end(3)

warden.region[1].region[1]:s_start(0)
warden.region[1].region[1]:s_end(1)

warden.region[1].region[1].loop[1]:f_start(0.3)
warden.region[1].region[1].loop[1]:f_len(0.2)

-- push bottom level loop to the first softcut voice

warden.region[1].region[1].loop[1]:push(1)

```
