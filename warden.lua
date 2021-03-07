local warden = {}
warden.help = [[ ]]

local buf_time = 16777216 / 48000 --exact time from the sofctcut source

local Slice = { is_slice = true }

-- create a new slice from an old slice (the warden object handles this)
function Slice:new(o)
    o = o or {}
    o.buffer = self.buffer

    --new bounds is assigned to old startend
    o.bounds = o.bounds or self.startend

    --new startend defaults to a copy of new bounds
    o.startend = o.startend or { o.bounds[1], o.bounds[2] }
    
    setmetatable(o, { __index = self })
    return o
end

function Slice:s_to_f(s) return s / self:get_boundary_length() end
function Slice:f_to_s(f) return f * self:get_boundary_length() end
function Slice:get_buffer() return table.unpack(self.buffer) end
function Slice:get_boundary_start() return self.bounds[1] end
function Slice:get_boundary_end() return self.bounds[2] end
function Slice:get_boundary_length() return self.bounds[2] - self.bounds[1] end

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
function Slice:get_length()
    return self.startend[2] - self.startend[1]
end
function Slice:phase_relative(phase, units)
    local s = phase - self.startend[1]
    if units == 'fraction' then return s / self:get_length()
    else return s end
end

function Slice:set_buffer(b) self.buffer = (type(b) == 'table') and b or { b } end
function Slice:set_start(t, units, abs)
    if abs == 'absolute' then self.startend[1] = t else
        t = (units == "fraction") and self:f_to_s(t) or t
        self.startend[1] = util.clamp(self.bounds[1], self.startend[2], t + self.bounds[1])
    end
end
function Slice:set_end(t, units, abs)
    if abs == 'absolute' then self.startend[2] = t else
        t = (units == "fraction") and self:f_to_s(t) or t
        self.startend[2] = util.clamp(self.startend[1], self.bounds[2], t + self.bounds[1])
    end
end
function Slice:set_length(t, units)
    t = (units == "fraction") and self:f_to_s(t) or t
    self.startend[2] = util.clamp(0, self.bounds[2], t + self.startend[1])
end

function Slice:update_voice(...)
    --re-clamp start/end
    self.startend[1] = util.clamp(self.bounds[1], self.bounds[2], self.startend[1])
    self.startend[2] = util.clamp(self.startend[1], self.bounds[2], self.startend[2])

    local b = self.buffer
    for i,v in ipairs {...} do
        softcut.loop_start(v, self.startend[1])
        softcut.loop_end(v, self.startend[2])
        softcut.buffer(v, b[(i - 1)%(#b) + 1])
    end
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
function Slice:read(file, start_src, ch_src)
    local dst = self
    start_src = start_src or 0
    ch_src = ch_src or 1

    if #self.buffer == 1 then
        softcut.buffer_read_mono(file, 
            start_src, dst.startend[1], dst:get_length(), 
            ch_src, dst.buffer[1]
        )
    else
        softcut.buffer_read_stereo(file, 
            start_src, dst.startend[1], dst:get_length()
        )
    end
end
function Slice:write(file)
    if #self.buffer == 1 then
        softcut.buffer_write_mono(file, self.startend[1], self:get_length(), self.buffer[1])
    else
        softcut.buffer_write_stereo(file, self.startend[1], self:get_length())
    end
end
function Slice:render(samples)
    softcut.render_buffer(self.buffer[1], self.startend[1], self:get_length(), samples)
end

warden.buffer = {
    Slice:new {
        startend = { 0, buf_time },
        buffer = { 1 }
    },
    Slice:new {
        startend = { 0, buf_time },
        buffer = { 2 }
    }
}
warden.buffer_stereo = {
    Slice:new {
        startend = { 0, buf_time },
        buffer = { 1, 2 }
    }
}

-- create n slices bound by the input
function warden.subloop(input, n)
    n = n or 1

    if input.is_slice and n == 1 then
        return input:new()
    elseif input.is_slice then
        local slices = {}
        for i = 1, n do slices[i] = warden.subloop(input, 1) end
        return slices
    else
        local slices = {}
        for k,v in pairs(input) do slices[k] = warden.subloop(v, n) end
        return slices
    end
end

-- divide input into n slices of equal length
function warden.divide(input, n)
    local slices = {}
    local divisions = {}

    local function add_divisions(slice, this_n)
        if slice.is_slice then
            table.insert(divisions, { n = this_n, slice = slice })
        else
            if this_n % #slice ~= 0 then 
                return 'warden.divide: n must be evenly divisible by the number of input slices!'
            end
            for k,v in pairs(slice) do
                add_divisions(v, this_n / #slice)
            end
        end
    end

    local err = add_divistions(input, n)
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
function warden.save(...)
    local t, n, name = split_arg(...)
    local filename = norns.state.data .. (name or 'warden') .. (n or 0) .. ".data"
    tab.save(t, filename)
end

--load save file to inputs, args: [input, ], file number, file name 
function warden.load(...)
    local t, n, name = split_arg(...)
    local filename = norns.state.data .. (name or 'warden') .. (n or 0) .. ".data"
    local data = tab.load(filename)
    
    local function set(t, data)
        if t.is_slice then
            t.startend[1] = data.startend[1]
            t.startend[2] = data.startend[2]
        else
            for k,v in pairs(t) do set(t[k], data[k]) end
        end
    end
    set(t, data)
end
