--[[
author: jie123108@163.com
date: 20151120
]]

local _M = {}

function _M.ifnull(var, value)
    if var == nil then
        return value
    end
    return var
end

function _M.trim (s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function _M.replace(s, s1, s2)
    local str = string.gsub(s, s1, s2)
    return str
end

function _M.endswith(str,endstr)
   return endstr=='' or string.sub(str,-string.len(endstr))==endstr
end

function _M.startswith(str,startstr)
   return startstr=='' or string.sub(str,1, string.len(startstr))==startstr
end

-- ngx.log(ngx.INFO, "config.idc_name:", config.idc_name, ", config.is_root:", config.is_root)
-- delimiter 应该是单个字符。如果是多个字符，表示以其中任意一个字符做分割。
function _M.split(s, delimiter)
    if s == nil then
        return nil
    end
    local result = {};
    for match in string.gmatch(s, "[^"..delimiter.."]+") do
        table.insert(result, match);
    end
    return result;
end

-- delim 可以是多个字符。
-- maxNb 最多分割项数
function _M.splitex(str, delim, maxNb)
    -- Eliminate bad cases...
    if delim == nil or string.find(str, delim) == nil then
        return { str }
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0    -- No limit
    end
    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local nb = 0
    local lastPos
    for part, pos in string.gmatch(str, pat) do
        nb = nb + 1
        result[nb] = part
        lastPos = pos
        if nb == maxNb then break end
    end
    -- Handle the last field
    if nb ~= maxNb then
        result[nb + 1] = string.sub(str, lastPos)
    end
    return result
end

return _M