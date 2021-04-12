local warden = {}
warden.help = [[ ]]

local buf_time = 16777216 / 48000 --exact time from the sofctcut source
local voice_count = 6

local Slice = { is_slice = true, children = {}, quantum = 0.01 }

--create a new slice from an old slice (the warden object handles this)
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
function Slice:get_length(units)
    local s = self.startend[2] - self.startend[1]
    if units == "fraction" then return self:s_to_f(s)
    else return s end
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
        self.startend[1] = util.clamp(t + self.bounds[1], self.bounds[1], self.startend[2])
    end
end
function Slice:set_end(t, units, abs)
    if abs == 'absolute' then self.startend[2] = t else
        t = (units == "fraction") and self:f_to_s(t) or t
        self.startend[2] = util.clamp(t + self.bounds[1], self.startend[1], self.bounds[2])
    end
end
function Slice:set_length(t, units)
    t = (units == "fraction") and self:f_to_s(t) or t
    self.startend[2] = util.clamp(t + self.startend[1], 0, self.bounds[2])
end
function Slice:delta_start(delta, units, abs)
    self:set_start(self:get_start(units, abs) + delta, units, abs)
end
function Slice:delta_end(delta, units, abs)
    self:set_end(self:get_end(units, abs) + delta, units, abs)
end
function Slice:delta_length(delta, units)
    self:set_length(self:get_length(units) + delta, units)
end

function Slice:expand()
    --self.startend = { self.bounds[1], self.bounds[2] }
    self.startend[1] = self.bounds[1]
    self.startend[2] = self.bounds[2]
    self:expand_children()
end
function Slice:expand_children()
    for i,v in ipairs(self.children) do
        v:expand()
    end
end
local headroom = 0
local function quant(self)
    if type(self.quantum) == 'function' then return self.quantum()
    else return self.quantum or 0.01 end
end
function Slice:punch_in()
    self.t = 0
    self.startend[1] = self.bounds[1]
    self:expand_children()

    self.clock = clock.run(function()
        while true do
            local q = math.abs(quant(self)) --in the future, use a getter for sofcut.rate
            clock.sleep(q)
            self.t = self.t + q
            self:set_end(self.t + headroom*q)
            self:expand_children()
        end
    end)
end
function Slice:punch_out()
    if self.clock then
        clock.cancel(self.clock)
        self:set_end(self.t)
        self:expand_children()
        self.t = 0
        self.clock = nil
    end
end

function Slice:update_voice(...)
    --re-clamp start/end
    self.startend[1] = util.clamp(self.startend[1], self.bounds[1], self.bounds[2])
    self.startend[2] = util.clamp(self.startend[2], self.startend[1], self.bounds[2])

    local b = self.buffer
    for i,v in ipairs {...} do
        softcut.loop_start(v, self.startend[1])
        softcut.loop_end(v, self.startend[2])
        softcut.buffer(v, b[(i - 1)%(#b) + 1])
    end
end
function Slice:position(voice, t, units)
    t = self.bounds[1] + ((units == "fraction") and self:f_to_s(t) or t)
    softcut.position(voice, t)
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

Bundle = { is_bundle = true }

function Bundle:new(o)
    o = o or {}

    setmetatable(o, {
        __index = function(t, k)
            if Bundle[k] ~= nil then return Bundle[k]
            else return function(s, n, ...)

                --search slices for assignment
                for k,slice in pairs(s) do
                    if slice.is_slice then ---------------------recursion needed
                        for j,vc in ipairs(slice.voices) do
                            if vc == n then
                                return slice[k](slice, ...)
                            end
                        end
                    else
                    end
                end

                local function search_children(sl)
                    for i,slice in ipairs(sl.children) do
                        for j,vc in ipairs(slice.voices) do
                            if vc == n then return true end
                        end
                        return search_children(slice)
                    end
                end

                --check for the assignment in slice ancestors
                for k,slice in pairs(s) do
                    if slice.is_slice then
                        if search_children(slice) then
                            return slice[k](slice, ...)
                        end
                    else
                    end
                end
            end end
        end
    })

    return o
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
warden.buffer_stereo = Slice:new {
    startend = { 0, buf_time },
    buffer = { 1, 2 }
}

warden.assignments = {}

-- assign input to voice indicies
function warden.assign(input, ...)
    local voices = { ... }
    if #voices == 0 then voices[1] = 1 end

    local function asgn(sl, vcs)
        if sl.is_slice then
            for _,n in ipairs(vcs) do
                if n <= voice_count then
                    if warden.assignments[n] then
                        warden.assinments[n].voices = {}
                    end
                    
                    warden.assignments[n] = sl
                    table.insert(sl.voices, n)
                else
                    print('warden.assign: cannot assign a voice index greater than ' .. voice_count)
                end
            end
        else
            for i,ssl in ipairs(sl) do
                asgn(ssl, { vcs[i] or (vcs[#vcs] + i - 1) })
            end
        end
    end

    asgn(input, voices)
end

-- create n slices bound by the input
function warden.subloop(input, n)
    n = n or 1

    if input.is_slice and n == 1 then
        return input:new()
    elseif input.is_slice then
        local slices = Bundle:new()
        for i = 1, n do slices[i] = warden.subloop(input, 1) end
        return slices
    else
        local slices = Bundle:new()
        for k,v in pairs(input) do slices[k] = warden.subloop(v, n) end
        return slices
    end
end

-- divide input into n slices of equal length
function warden.divide(input, n)
    local slices = Bundle:new()
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

return warden
