-- Copyright (C) 2015 Xiaojie Liu (jie123108@163.com).
-- 
--[[
author: jie123108@163.com
date: 20151206
]]

local mongo = require "resty.mongol"

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


local function get_all_collections(mongo_cfg)
	local ok, conn = conn_get(mongo_cfg)
	if not ok then
		return ok, conn
	end
	local dbname = mongo_cfg.dbname or "ngx_stats"
	local db = conn:new_db_handle(dbname)
	local colls = db:listcollections()
	local collnames = {}
	for i, coll in colls:pairs() do 
		if coll.name then
			local name = string.sub(coll.name, #dbname + 2)
			if not string.find(name, "%.") then
				table.insert(collnames, name)
			end
		end
	end
	conn_put(conn)

	return true, collnames
end

local function get_stats(mongo_cfg, collname, date)
	local ok, conn = conn_get(mongo_cfg)
	if not ok then
		return ok, conn
	end
	ngx.log(ngx.INFO, "-------", collname, ", date:", date)
	local stats = {}
	local dbname = mongo_cfg.dbname or "ngx_stats"
	local db = conn:new_db_handle(dbname)
	local coll = db:get_col(collname)
	local query = {date=date}
	local cursor = coll:find(query)
	if cursor then
		local tmp_stats,err = cursor:sort({count=-1})
		if err then
			ngx.log(ngx.ERR, "cursor:sort failed! err:", tostring(err))
		elseif tmp_stats and type(tmp_stats) == 'table' then
			for _, s in ipairs(tmp_stats) do 
				s['_id'] = nil
			end
			stats = tmp_stats
		end
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
}
