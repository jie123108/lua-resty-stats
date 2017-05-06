--[[
author: jie123108@163.com
date: 20151130
]]
local json = require("resty.stats.json")
local mongo_dao = require("resty.stats.mongo_dao")
local util = require("resty.stats.util")

local ngx_log = ngx.log

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(5, 5)
_M.debug = false
_M.flushing = false
_M.stats = new_tab(100, 100)
_M.has_stats = false
_M.flush_interval = 10 -- 10 seconds
_M.max_retry_times = 3
_M.retry_interval = 0.2 -- second
_M.mongo_cfg = nil

function _M.init(mongo_cfg, flush_interval, retry_interval)
    assert(mongo_cfg ~= nil, "mongo_cfg is a nil")
    _M.mongo_cfg = mongo_cfg 

    if flush_interval then
        _M.flush_interval = flush_interval
    end
    if retry_interval then 
        _M.retry_interval = retry_interval
    end
end

function _M.write_stats(stats)   
    local write_count = 0
    local retrys = _M.max_retry_times
    for stats_key, update in pairs(stats) do 
        local arr = util.splitex(stats_key, "#|#", 2)
        if #arr == 2 then
            local collname = arr[1]
            local selector = arr[2]
            local debug_sql = 

            ngx.log(ngx.DEBUG, "write_stats: db.", collname, ".update(", selector, ",", json.dumps(update), ",{upsert: true});")

            selector = json.loads(selector)
            local dao = mongo_dao:new(_M.mongo_cfg, collname)
            for i=1, retrys do
                local ok, err = dao:upsert(selector, update)
                if not ok then
                    if i < retrys then
                        ngx.log(ngx.WARN, "db.", collname, ".update(", json.dumps(selector), ",", json.dumps(update), ",{\"upsert\": true}) failed! err:", tostring(err))
                        ngx.sleep(_M.retry_interval or 0.3 * i)

                    else
                        ngx.log(ngx.ERR, "db.",collname, ".update(", json.dumps(selector), ",", json.dumps(update), ",{\"upsert\": true}) failed! err:", tostring(err))
                    end
                else
                    write_count = write_count + 1
                    if _M.debug then
                        ngx.log(ngx.INFO, "db.",collname, ".update(", json.dumps(selector), ",", json.dumps(update), ",{\"upsert\": true}) ok! err:", tostring(err))
                    end
                    break
                end
            end 
        else 
            ngx.log(ngx.ERR, "invalid stats_key[", stats_key, "] ...")
        end
    end 

    return true, write_count
end

function _M.do_flush()
    if not _M.has_stats then
        return
    end

    if _M.stats_send == nil then
        _M.stats_send = _M.stats
        _M.stats = new_tab(100, 100)
        _M.has_stats = false
    end 

    if _M.debug then
        ngx_log(ngx.INFO, " begin do flush!")
    end

    if _M.flushing then
        ngx_log(ngx.INFO, "previous flush not finished")
        return true
    else
        if _M.debug then
            ngx_log(ngx.INFO, " get flush lock...")
        end
        _M.flushing = true
    end
    if _M.stats_send == nil then
        if _M.debug then
            ngx_log(ngx.INFO, " no stats to flush! release flush lock!")
        end
        _M.flushing = false
        _M.stats_send = nil
        return true
    end
    local log_count = 0
    local ok, err = _M.write_stats(_M.stats_send)
    if _M.debug then
        ngx_log(ngx.INFO, "end to flush the stats!")
    end
    if ok then
        if type(err) == 'number' and err > 0 then
            ngx_log(ngx.INFO, "success to flush ", err, " stats to db!")
        end
    else
        ngx_log(ngx.ERR, "failed to flush stats to db! err:", err, ", ", log_count, " stats will dropped!")
    end
    _M.stats_send = nil

    _M.flushing = false
    if _M.debug then
        ngx_log(ngx.INFO, " release flush lock...")
    end
end

local function inc_merge_table(values, to_values)
    for field, value in pairs(values) do 
        local to_value = to_values[field]
        if to_value == nil then
            to_values[field] = value 
        elseif type(value) == 'number' then
            to_values[field] = to_value + value
        elseif type(value) == 'table' then
            if type(to_value) == 'table' then
                inc_merge_table(value, to_value)
            else 
                ngx.log(ngx.WARN, "$inc." .. field .. " target is not a table, will droped!")
                to_values[field] = value 
            end
        else 
            ngx.log(ngx.ERR, '$inc.' .. field .. "'s value must a number")
        end
    end
end

local function merge_stats(from, to)
    for op, values in pairs(from) do 
        local to_values = to[op]
        if to_values == nil then
            to[op] = values
        else 
            if op == "$inc" then
                if type(values) == 'table' then            
                    inc_merge_table(values, to_values)
                else 
                    ngx.log(ngx.ERR, "$inc's value must be a 'table'")
                end
            elseif op == "$set" then
                if type(values) == 'table' then            
                    -- $set 操作，直接使用新的值，覆盖旧的值。
                    to[op] = values
                else 
                    ngx.log(ngx.ERR, "$set's value must be a 'table'")
                end
            else 
                ngx.log(ngx.ERR, "unprocessed mongodb operator [", op, "] ...")
            end
        end
    end
end

function _M.add_stats(table_name, selector, update)
    _M.has_stats = true
    if _M.debug then
        ngx_log(ngx.INFO, "merge a stats..")
    end
    selector = json.dumps(selector)
    local stats_key = string.format("%s#|#%s", table_name, selector)

    if _M.stats[stats_key] == nil then
        _M.stats[stats_key] = update
    else 
        merge_stats(update, _M.stats[stats_key])
    end
end


local function start_stats_flush_timer()
    local stats_flush_callback = function(premature)
        _M.do_flush()
        start_stats_flush_timer()
    end
    
    local next_run_time = _M.flush_interval
    next_run_time = (next_run_time - ngx.time()%next_run_time)

    --ngx.log(ngx.INFO, " [start_stats_flush_timer] next run time:", next_run_time)
    local ok, err = ngx.timer.at(next_run_time, stats_flush_callback)
    if not ok then
        ngx.log(ngx.ERR, "failed to create timer: ", err)
        return
    end
end

_M.start_stats_flush_timer = start_stats_flush_timer

return _M