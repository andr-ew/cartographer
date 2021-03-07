# warden

simplify the division of softcut buffer space into arbitrary recording and/or playback regions & sub-regions


# usage

`divide`: split the parent area into evenly sized sub areas, returns a table of areas

`subloop`: create an area the same size of the parent area, with boundaries clamped to the parent area

`update_voice`: assign the start point, end point, & buffer number of the object to softcut voice

# example

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

