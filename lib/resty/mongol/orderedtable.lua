
local setmetatable = setmetatable
local t_insert = table.insert
local rawget,rawset = rawget,rawset

local ordered_mt = {}
ordered_mt.__newindex = function(t,key,value)
    local _keys = t._keys
    if rawget(t,key) == nil then
        t_insert(_keys,key)
        rawset(t,key,value)
    else
        rawset(t,key,value)
    end
end

function ordered_mt.__pairs(t)
    local _i = 1
    local _next = function(t,k)
        local _k = rawget(t._keys,_i)
        if _k == nil then
            _i = 1
            return nil
        end
        local _v =  rawget(t,_k)
        if _v == nil then
            _i = 1
            return nil
        end
        _i = _i + 1
        return _k,_v
    end
    return _next,t
end

local function merge(self,t)
    if type(t) ~= "table" then
        return
    end
    for k,v in pairs(t) do
        self[k] = v
    end
    return self
end

local function ordered_table(a)
    local t = { _keys = {} }
    t.merge = merge
    setmetatable(t,ordered_mt)
    if a then
        for i=1,#a,2 do
            t[a[i]] =  a[i+1]
        end
    end
    return t, ordered_mt
end

return ordered_table