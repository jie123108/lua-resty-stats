-- Copyright (C) 2015 Xiaojie Liu (jie123108@163.com).
-- 
--[[
author: jie123108@163.com
date: 20151127
]]

local json = require("resty.stats.json")
local coll_util = require("resty.stats.coll_util")
local cache = require("resty.stats.cache")

local VAR_PATTERM = "(\\$[a-zA-Z0-9_]+)"

local function date() return string.sub(ngx.localtime(), 1, 10) end
local function time() return string.sub(ngx.localtime(), 12) end
local function year() return string.sub(ngx.localtime(), 1,4) end
local function month() return string.sub(ngx.localtime(), 6,7) end
local function day() return string.sub(ngx.localtime(), 9,10) end
local function hour() return string.sub(ngx.localtime(), 12,13) end
local function minute() return string.sub(ngx.localtime(), 15,16) end
local function second() return string.sub(ngx.localtime(), 18,19) end

local def_vars = {
    now = ngx.time, 
    date = date,
    time = time,
    year = year,
    month = month,
    day = day,
    hour = hour,
    minute = minute,
    second = second
}

local function get_variable_value(values, key)
    local value = values[key];
    if value then
        return value 
    end

    if def_vars[key] then
       return def_vars[key]()
    end

    return "-"
end

local function var_format(format, values)
    if type(format) ~= 'string' then
        return format
    end

    local replace = function(m)
        local var = string.sub(m[0], 2)
        local value = get_variable_value(values, var)
        return value
    end
    local newstr, n, err = ngx.re.gsub(format, VAR_PATTERM, replace)

    return newstr, err
end

local _M = {}

_M._VERSION = '1.00'

_M.def_mongo_cfg = { host = "127.0.0.1",port = 27017, dbname = "ngx_stats"}

--[[
--可用的变量：
$now: 系统当前时间(秒), unixtime
$date, 当前时间日期部分。输出格式为：yyyy-MM-dd
$time, 当前时间时间部分。输出格式为：hh:mm:ss
$year,$month,$day 分别为年月日，长度分别为4,2,2。
$hour,$minute,$second 分别为时分秒。
]]
-- selector 更新使用的查询子
-- update 更新语句。
-- indexes 更新查询需要用到的索引的字段。
local def_stats_configs = {
    stats_host={
        selector={date='$date',key='$host'}, 
        update={['$inc']= {count=1, ['hour_cnt.$hour']=1, ['status.$status']=1, 
                    ['req_time.all']="$request_time", ['req_time.$hour']="$request_time"}},
        indexes={
            {keys={'date', 'key'}, options={unique=true}},
            {keys={'key'}, options={}}
        }
    }
}

local stats_configs = {}

local function check_stats_config(stats_name, stats_config)
    local selector = stats_config.selector
    local update = stats_config.update

    assert(selector ~= nil and type(selector)=='table', stats_name .. "'s selector must a table")
    assert(update ~= nil and type(update)=='table', stats_name .. "'s update must a table")

    for op, values in pairs(update) do 
        assert(type(values)=='table', stats_name .. "'s value of '" .. op .. "' type must be a table" )
        if op == "$inc" then
            -- for field, value in pairs(values) do 
            --     assert(type(value)=='number', "$inc." .. field .. "'s value [" .. tostring(value) .. "] must be a number!")
            -- end
        elseif op == "$set" then

        else 
            assert(false, stats_name .. "'s unknow mongodb operator '" .. op .. "'")
        end
    end
end

local function check_config(stats_config)
    for stats_name, stats_config in pairs(stats_config) do 
        check_stats_config(stats_name, stats_config)
    end
end 

local mongo_ops = {
    ["$inc"] = true,
    ["$mul"] = true,
    ["$rename"] = true,
    ["$setOnInsert"] = true,
    ["$set"] = true,
    ["$unset"] = true,
    ["$min"] = true,
    ["$max"] = true,
    ["$currentDate"] = true,
    ["$addToSet"] = true,
    ["$pop"] = true,
    ["$pullAll"] = true,
    ["$pull"] = true,
    ["$pushAll"] = true,
    ["$push"] = true,
    ["$each"] = true,
    ["$slice"] = true,
    ["$sort"] = true,
    ["$position"] = true,
    ["$bit"] = true,
    ["$isolated"] = true,
}
local function table_format(t, jso, output, parent_op)
    assert(type(t)=='table')

    if output == nil then
        output = {}
    end

    for k, v in pairs(t) do 
        local vtype = type(v)
        if type(k) == 'number' then
            k = k -1
        elseif type(k) == 'string' and (not mongo_ops[k]) then
            k = var_format(k, jso)
        end
        if vtype == 'string' then
            local value = var_format(v, jso)
            if parent_op == "$inc" then
                value = tonumber(value) or 0
            end
            output[k] = value
        elseif vtype == 'table' then
            output[k] = table_format(v, jso, nil, k)
        else
            output[k] = v
        end
    end

    return output
end

--[[
stats_name: stats name and table name.
stats_config:
    -- selector: the mongodb update selector
    -- update: the mongodb update statement
    -- indexes the indexes of the selector used.
    eg.:
stats_name: stats_host
stats_config: 
    {
        selector={date='$date',key='$host'}, 
        update={['$inc']= {count=1, ['hour_cnt.$hour']=1, ['status.$status']=1, 
                    ['req_time.all']="$request_time", ['req_time.$hour']="$request_time"}},
        indexes={
            {keys={'date', 'key'}, options={unique=true}},
            {keys={'key'}, options={}}
        }
    }
]]
function _M.add_stats_config(stats_name, stats_config)
    check_stats_config(stats_name, stats_config)
    if stats_configs[stats_name] then
        return false, "stats_name [" .. stats_name .. "] exist!"
    end
    stats_configs[stats_name] = stats_config
end

function _M.get_stats_names()
    local names = {}
    for k, _ in pairs(stats_configs) do 
        table.insert(names, k)
    end
    return names
end

-- add the default stats configs
function _M.add_def_stats()
    for stats_name, stats_config in pairs(def_stats_configs) do 
        _M.add_stats_config(stats_name, stats_config)
    end
end

function _M.init(mongo_cfg, flush_interval, retry_interval)
    _M.mongo_cfg = mongo_cfg or _M.def_mongo_cfg
    cache.init(_M.mongo_cfg, flush_interval, retry_interval)
    check_config(stats_configs)
    local function create_index_callback(premature, stats_configs, mongo_cfg)
        for stats_name, stats_config in pairs(stats_configs) do 
            local indexes = stats_config.indexes
            if indexes then
                local collection = stats_name  
                local ok, err = coll_util.create_coll_index(mongo_cfg, collection, indexes) 
                ngx.log(ngx.INFO, "create_coll_index(", collection, ") ok:", tostring(ok), ", err:", tostring(err)) 
            end
        end
    end
    local ok, err = ngx.timer.at(0, create_index_callback, stats_configs, _M.mongo_cfg)
    if not ok then
        ngx.log(ngx.ERR, "failed to create timer: ", err)
        return
    end

    cache.start_stats_flush_timer()
end

function _M.log(stats_name)
    local values = ngx.var 
    local function log_format(stats_name, stats_config)
        local fmt_selector = stats_config.selector
        local fmt_update = stats_config.update
        local selector = table_format(fmt_selector, values)
        local update = table_format(fmt_update, values)
        cache.add_stats(stats_name, selector, update)
    end
    if stats_name == nil then
        for stats_name, stats_config in pairs(stats_configs) do 
            log_format(stats_name, stats_config)
        end
    else 
        local stats_config = stats_configs[stats_name]
        assert(stats_config ~= nil, "stats '" .. stats_name .. "' not exist!")
        log_format(stats_name, stats_config)
    end
end


return _M
