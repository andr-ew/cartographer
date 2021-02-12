local warden = {}
local slice = {
    bounds = { 0, 0 },
    limit = { 0, 0 }
}

-- create a new slice from an old slice
function slice:new(o)
    o = o or {}
    o = setmetatable(o, { __index = self })

    --new limit is set to old bounds
    o.limit = self.bounds

    --new bounds defaults to a copy of old bounds
    o.bounds = {
        self.bounds[1],
        self.bounds[2]
    }

    return o
end

local slice = {
    bounds = { 0, 0 },

}

warden.buffer = {}
buf_time = 16777216 / 48000 --exact time from the sofctcut source
