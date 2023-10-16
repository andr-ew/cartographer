local cartographer = {}
cartographer.help = [[ ]]

local buf_time = 16777216 / 48000 --exact time from the sofctcut source
local voice_count = 6

local Slice = { is_slice = true, children = {} }

--create a new slice from an old slice (the cartographer object handles this)
function Slice:new(o)
    o = o or {}
    o.children = {}

    o.voices = {}

    o.buffer = rawget(o, 'buffer') or self.buffer

    --new bounds is assigned to old startend
    o.bounds = rawget(o, 'bounds') or self.startend

    --new startend defaults to a copy of new bounds
    o.startend = rawget(o, 'startend') or { o.bounds[1], o.bounds[2] }
    
    table.insert(self.children, o)
    setmetatable(o, { __index = self })
    return o
end

--private
function Slice:s_to_f(s) return s / self:get_boundary_length() end
function Slice:f_to_s(f) return f * self:get_boundary_length() end
function Slice:get_buffer() return table.unpack(self.buffer) end
function Slice:get_boundary_start() return self.bounds[1] end
function Slice:get_boundary_end() return self.bounds[2] end
function Slice:get_boundary_length() return self.bounds[2] - self.bounds[1] end
--/private

function Slice:seconds_to_fraction(s) 
    local len = self:get_length()
    return len > 0 and (s / len) or 0
end
function Slice:fraction_to_seconds(f) return f * self:get_length() end

function Slice:get_start(units, abs) 
    if abs == 'absolute' then return self.startend[1] end
    
    local s = self.startend[1] - self.bounds[1] 
    if units == "fraction" then return self:s_to_f(s)
    else return s end
end
function Slice:get_end(units, abs)
    if abs == 'absolute' then return self.startend[2] end

    local s = self.startend[2] - self.bounds[1] 
    if units == "fraction" then return self:s_to_f(s)
    else return s end
end
function Slice:get_length(units)
    local s = self.startend[2] - self.startend[1]
    if units == "fraction" then return self:s_to_f(s)
    else return s end
end
function Slice:phase_relative(phase, units)
    local s = phase - self.startend[1]
    local len = self:get_length()
    if units == 'fraction' then return len > 0 and (s / self:get_length()) or 0
    else return s end
end

function Slice:update()
    --re-clamp start/end
    self.startend[1] = util.clamp(self.startend[1], self.bounds[1], self.bounds[2])
    self.startend[2] = util.clamp(self.startend[2], self.startend[1], self.bounds[2])

    local b = self.buffer
    for i,v in ipairs(self.voices) do
        softcut.loop_start(v, util.clamp(self.startend[1], 0, buf_time))
        softcut.loop_end(v, util.clamp(self.startend[2], 0, buf_time))
        softcut.buffer(v, b[(i - 1)%(#b) + 1])
    end

    --propagate downward
    for i,v in ipairs(self.children) do
        v:update()
    end
end

function Slice:set_buffer(b, silent) 
    self.buffer = (type(b) == 'table') and b or { b } 
    if not silent then self:update() end
end
function Slice:set_start(t, units, abs, silent)
    if abs == 'absolute' then self.startend[1] = t else
        t = (units == "fraction") and self:f_to_s(t) or t
        self.startend[1] = util.clamp(t + self.bounds[1], self.bounds[1], self.startend[2])
    end
    if not silent then self:update() end
end
function Slice:set_end(t, units, abs, silent)
    if abs == 'absolute' then self.startend[2] = t else
        t = (units == "fraction") and self:f_to_s(t) or t
        self.startend[2] = util.clamp(t + self.bounds[1], self.startend[1], self.bounds[2])
    end
    if not silent then self:update() end
end
function Slice:set_length(t, units, silent)
    t = (units == "fraction") and self:f_to_s(t) or t
    self.startend[2] = util.clamp(t + self.startend[1], 0, self.bounds[2])
    if not silenth then self:update() end
end
function Slice:delta_start(delta, units, abs, silent)
    self:set_start(self:get_start(units, abs) + delta, units, abs, silent)
end
function Slice:delta_end(delta, units, abs, silent)
    self:set_end(self:get_end(units, abs) + delta, units, abs, silent)
end
function Slice:delta_length(delta, units, silent)
    self:set_length(self:get_length(units) + delta, units, silent)
end
function Slice:delta_startend(delta, units, silent)
    local t = (units == "fraction") and self:f_to_s(delta) or delta
    if self.startend[2] + t < self.bounds[2] 
        and self.startend[1] + t > self.bounds[1] 
    then
        for i = 1,2 do self.startend[i] = self.startend[i] + t end
        if not silent then self:update() end
    end
end

function Slice:expand(silent)
    --self.startend = { self.bounds[1], self.bounds[2] }
    self.startend[1] = self.bounds[1]
    self.startend[2] = self.bounds[2]
    self:expand_children()
    if not silent then self:update() end
end
function Slice:expand_children(silent)
    for i,v in ipairs(self.children) do
        v:expand(silent)
    end
end
local headroom = 1
local function rate(self)
    if type(self.rate_callback) == 'function' then 
        return math.abs(self.rate_callback())
    else return 1 end
end
function Slice:punch_in()
    self.t = 0
    self:expand()
    self:trigger()

    self.metro = metro.init(function()
        if self.metro then
            -- clock.sleep(0.01)
            self.t = self.t + (0.01*rate(self))
            --self:set_end(self.t + headroom*q)
            self.startend[2] = self.bounds[1] + self.t + (headroom * rate(self))
            self:expand_children(true)
        end
    end, 0.01)

    self.metro:start()
end
function Slice:punch_out()
    if self.metro then
        self.metro:stop()
        self.metro = nil
        -- clock.cancel(self.clock)
        
        self:set_end(self.t)
        self:expand_children()
        self.t = 0
    end
end

function Slice:position(t, units)
    local p = self.startend[1] + ((units == "fraction") and self:f_to_s(t) or t)
    for i,v in ipairs(self.voices) do
        softcut.position(v, p)
    end
    for i,v in ipairs(self.children) do v:position(t, units) end -- convert to local scale ?
end
function Slice:trigger()
    self:position(0)
end
function Slice:clear()
    if #self.buffer == 1 then
        softcut.buffer_clear_region_channel(self.buffer[1], self.startend[1], self.startend[2])
    else
        softcut.buffer_clear_region(self.startend[1], self.startend[2])
    end
end
function Slice:copy(src, fade_time, reverse)
    local dst = self
    if #self.buffer == 1 then
        softcut.buffer_copy_mono(
            src.buffer[1], dst.buffer[1],
            src.startend[1], dst.startend[1],
            dst:get_length(), fade_time, reverse
        )
    else
        softcut.buffer_copy_stereo(
            src.startend[1], dst.startend[1],
            dst:get_length(), fade_time, reverse
        )
    end
end
--FIXME: might need to add padding at the beginning also, to account for reverse playback (crossfade at the beginning). this won't be possible if slice boundary starts at 0, so user will have to compensate for that (warden.buffer[1, 2]:set_start(padding))
function Slice:read(file, start_src, ch_src, length, padding)
    local dst = self
    start_src = start_src or 0
    ch_src = ch_src or 1
    length = length or 'destination'
    padding = padding or 0.1

    if length == 'source' or length == 'src' then
        local ch, samples, rate = audio.file_info(file)
        if samples then
            local len = (samples/rate) - padding
            dst:set_length(len - start_src)
        else
            print("cartographer: couldn't load file info for "..file)
        end
    end

    if #self.buffer == 1 then
        softcut.buffer_read_mono(file, 
            start_src, dst.startend[1], dst:get_length() + padding, 
            ch_src, dst.buffer[1]
        )
    else
        softcut.buffer_read_stereo(file, 
            start_src, dst.startend[1], dst:get_length() + padding
        )
    end
end
function Slice:write(file, padding)
    padding = padding or 0.1
    if #self.buffer == 1 then
        softcut.buffer_write_mono(
            file, self.startend[1], self:get_length() + padding, self.buffer[1]
        )
    else
        softcut.buffer_write_stereo(
            file, self.startend[1], self:get_length() + padding
        )
    end
end
function Slice:render(samples)
    softcut.render_buffer(self.buffer[1], self.startend[1], self:get_length(), samples)
end

-- return a function that checks the args coming from the softcut.event_render callback & calls func if the start & buffer match.
-- NOTE: beware of rendering multiple slices with the same buffer & start poins that are less than 1 second apart (rounding is neccesary)
function Slice:event_render(func)
    return function(ch, start, i, s)
        if ch == self.buffer[1] and util.round(start) == util.round(self.startend[1]) then
            func(i, s)
        end
    end
end

local Bundle = { is_bundle = true }

function Bundle:new(o)
    o = o or {}

    setmetatable(o, {
        __index = function(t, k)
            if Bundle[k] ~= nil then return Bundle[k]
            else return function(s, n, ...)
                local sl = s:get_slice(n)
                if sl then return sl[k](sl, ...) 
                else print('Bundle.' .. k .. ': no voice assignment at index ' .. n) end
            end end
        end
    })

    return o
end

--recursive search bundle for slice assigned to voice n or closest ancestor
function Bundle:get_slice(n)
    local ret

    --recursion mania !
    local function bundle_do(input, f)
        if input.is_slice == true then 
            local r = f(input)
            if r then return r end
        else for i,v in pairs(input) do
            local r = bundle_do(v, f)
            if r then return r end
        end end
    end
    local function search_voices(slice)
        for j,vc in ipairs(slice.voices) do
            if vc == n then return slice end
        end
    end
    local function search_children(slice)
        for i,sl in ipairs(slice.children) do
            if search_voices(sl) or search_children(sl) then return slice end
        end
    end
    
    --search slices for assignment
    ret = bundle_do(self, search_voices)
    if ret then return ret end

    --check for the assignment in slice ancestors
    ret = bundle_do(self, search_children)
    if ret then return ret end
end

cartographer.buffer = {
    Slice:new {
        startend = { 0, buf_time },
        buffer = { 1 }
    },
    Slice:new {
        startend = { 0, buf_time },
        buffer = { 2 }
    }
}
cartographer.buffer_stereo = Slice:new {
    startend = { 0, buf_time },
    buffer = { 1, 2 }
}

cartographer.assignments = {}

-- assign input to voice indicies
function cartographer.assign(input, ...)
    local voices = { ... }
    if #voices == 0 then voices[1] = 1 end

    local function asgn(sl, vcs)
        if sl.is_slice == true then
            for _,n in ipairs(vcs) do
                if n <= voice_count then
                    if cartographer.assignments[n] then
                        local t = cartographer.assignments[n].voices
                        local i = tab.key(t, n)
                        if i then table.remove(t, i) end
                    end
                    
                    cartographer.assignments[n] = sl
                    table.insert(sl.voices, n)
                else
                    print('cartographer.assign: cannot assign a voice index greater than ' .. voice_count)
                end
            end
            sl:update()
            --sl:trigger()
        else
            for i,ssl in ipairs(sl) do
                asgn(ssl, { vcs[i] or (vcs[#vcs] + i - 1) })
            end
        end
    end

    asgn(input, voices)
    -- for _,n in ipairs(voices) do
    --     softcut.position(n, input:get_start(n, 'seconds', 'absolute'))
    -- end
end

-- create n slices bound by the input
function cartographer.subloop(input, n)
    n = n or 1

    if input.is_slice == true and n == 1 then
        return input:new()
    elseif input.is_slice == true then
        local slices = Bundle:new()
        for i = 1, n do slices[i] = cartographer.subloop(input, 1) end
        return slices
    else
        local slices = Bundle:new()
        for k,v in pairs(input) do 
            slices[k] = cartographer.subloop(v, n) 
        end
        return slices
    end
end

-- divide input into n slices of equal length
function cartographer.divide(input, n)
    local slices = Bundle:new()
    local divisions = {}

    local function add_divisions(slice, this_n)
        if slice.is_slice == true then
            table.insert(divisions, { n = this_n, slice = slice })
        else
            if this_n % #slice ~= 0 then 
                return 'cartographer.divide: n must be evenly divisible by the number of input slices!'
            end
            for k,v in pairs(slice) do
                add_divisions(v, this_n / #slice)
            end
        end
    end

    local err = add_divisions(input, n)
    if err then print(err); return end

    for _, div in ipairs(divisions) do
        local n, slice = div.n, div.slice

        local step = (slice.startend[2] - slice.startend[1]) / n
        local startend = { 0, 0 + step }

        for i = 1, n do
            table.insert(slices, slice:new { startend = startend })
            startend = { startend[1] + step, startend[2] + step }
        end
    end

    return slices
end

local tab = require 'tabutil'
local function split_arg(...)
    local t, arg = {}, { ... }
    for i,v in ipairs(arg) do
        if type(v) == 'table' then
            table.insert(table.remove(arg, i))
        end
    end
    return t, table.unpack(arg)
end

--save inputs to disk, args: [input, ], file number, file name
function cartographer.save(...)
    local t, n, name = split_arg(...)
    local filename = norns.state.data .. (name or 'cartographer') .. (n or 0) .. ".data"
    tab.save(t, filename)
end

--load save file to inputs, args: [input, ], file number, file name 
function cartographer.load(...)
    local t, n, name = split_arg(...)
    local filename = norns.state.data .. (name or 'cartographer') .. (n or 0) .. ".data"
    local data = tab.load(filename)
    
    local function set(t, data)
        if t.is_slice == true then
            t.startend[1] = data.startend[1]
            t.startend[2] = data.startend[2]
        else
            for k,v in pairs(t) do set(t[k], data[k]) end
        end
    end
    set(t, data)
end

return cartographer, Slice, Bundle
