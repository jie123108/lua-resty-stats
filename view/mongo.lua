-- Copyright (C) 2015 Xiaojie Liu (jie123108@163.com).
-- 
--[[
author: jie123108@163.com
date: 20151206
]]

local mongo = require "resty.mongol"
local json = require("resty.stats.json")

local function conn_get(mongo_cfg)
	local conn = mongo:new()
	if mongo_cfg.timeout then
    	conn:set_timeout(mongo_cfg.timeout) 
    end
    local host = mongo_cfg.host or "127.0.0.1"
    local port = mongo_cfg.port or 1000*10
    local ok, err = conn:connect(host, port)
    if not ok then
        ngx.log(ngx.ERR, "connect to mongodb (", host, ":", port, ") failed! err:", tostring(err))
        return ok, err
    end

    -- local db = conn:new_db_handle(self.dbname)
    -- local coll = db:get_col(self.collname)
    return ok, conn
end

local function conn_put(conn)
	conn:set_keepalive()
end

local function stats_filter_by_key(stats_list, key_pattern)
	if key_pattern == nil or key_pattern == "" then 
		return stats_list
	end
	local stats_new = {}
	for _, stats in ipairs(stats_list) do 
		if stats.key and ngx.re.match(stats.key,key_pattern) then 
			table.insert(stats_new, stats)
		end
	end

	return stats_new
end


local function add_percent(stats_list)
	local total = 0
	for i, stats in ipairs(stats_list) do 
		local count = stats.count or 0
		total = total + count
	end
	if total > 0 then
		for i, stats in ipairs(stats_list) do 
			local count = stats.count or 0
			local percent = (count*1.0 / total) * 100.0
			stats.percent = percent
			stats.total = total
		end
	end
end

local function mongo_find(coll, selector, sortby, skip, limit)
	local objs = {}
	skip = skip or 0
    local cursor, err = coll:find(selector, {_id=0}, limit)
    if cursor then
    	if skip then
    		cursor:skip(skip)
    	end
    	if limit then
    		cursor:limit(limit)
    	end
    	if sortby then
    		cursor:sort(sortby)
    	end
        for index, item in cursor:pairs() do
            table.insert(objs, item)
        end
    end

    if err then
        return false, err
    else
        return true, objs
    end
end


local function get_stats(mongo_cfg, collname, date, key_pattern, limit)
	local ok, conn = conn_get(mongo_cfg)
	if not ok then
		return ok, conn
	end
	ngx.log(ngx.INFO, "------- collection:", collname, ", date:", date)
	local stats = {}
	local dbname = mongo_cfg.dbname or "ngx_stats"
	local db = conn:new_db_handle(dbname)
	local coll = db:get_col(collname)
	local query = {date=date}
	local skip = 0
	limit = limit or 300
	local sortby = {count=-1}
	local ok, tmp_stats = mongo_find(coll, query, sortby, skip, limit)
	if ok then
		if tmp_stats and type(tmp_stats) == 'table' then
			stats = stats_filter_by_key(tmp_stats, key_pattern)
			add_percent(stats)
		end
	else
		ngx.log(ngx.ERR, "mongo_query(", json.dumps(query), ") failed! err:", tmp_stats)
	end
	conn_put(conn)

	return true, stats
end

local function get_stats_by_key(mongo_cfg, collname, key, limit)
	local ok, conn = conn_get(mongo_cfg)
	if not ok then
		return ok, conn
	end
	ngx.log(ngx.INFO, "------- collection:", collname, ", key:", key)
	local stats = {}
	local dbname = mongo_cfg.dbname or "ngx_stats"
	local db = conn:new_db_handle(dbname)
	local coll = db:get_col(collname)
	local query = {key=key}
	local skip = 0
	limit = limit or 300
	-- local ok, tmp_stats = mongo_query(coll, query, offset, limit)
	local sortby = {date=-1}
	local ok, tmp_stats = mongo_find(coll, query, sortby, skip, limit)
	if ok then
		if tmp_stats and type(tmp_stats) == 'table' then
			stats = tmp_stats
		end
	else
		ngx.log(ngx.ERR, "mongo_query(", json.dumps(query), ") failed! err:", tmp_stats)
	end
	conn_put(conn)
	return true, stats
end

-- get_all_collections({host="127.0.0.1", port=27017})
-- local ok, stats = get_stats({host="127.0.0.1", port=27017}, "stats_uri", "2015-12-07")
-- cjson = require "cjson"
-- ngx.say("stats:", cjson.encode(stats))

return {
	get_all_collections = get_all_collections,
	get_stats = get_stats, 
	get_stats_by_key = get_stats_by_key,
}
