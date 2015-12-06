--[[
author: jie123108@163.com
date: 20151120
comment: create collection index。
]]

local mongo_dao = require("resty.stats.mongo_dao")
local util = require("resty.stats.util")
local t_ordered = require("resty.stats.orderedtable")

local _M = {}


-- created indexes
_M.exist_indexes = {}

-- create index if not exist!
function _M.create_coll_index(mongo_cfg, collection, index_keys, index_options)
	if _M.exist_indexes[collection] then
		return true, "idx-exist"
	end
		
	local dao = mongo_dao:new(mongo_cfg, collection)
	local ok, err = nil
	
	local keys = t_ordered({})
	for _, key in ipairs(index_keys) do 
		keys[key] = 1
	end
	local options = {unique=true}
	if index_options then
		for k, v in pairs(index_options) do 
			options[k] = v
		end
	end
	ok, err, idx_name = dao:ensure_index(keys,options)
	if ok then
		ngx.log(ngx.INFO, "create index [",tostring(idx_name), "] for [", collection, "] success! ")
	else
		local err = tostring(err)
		if(string.find(err, "already exists")) then
			ok = true
		end
		ngx.log(ngx.ERR, "create index [",tostring(idx_name), "] for [", collection, "] failed! err:", err)
	end

	-- dao:uninit()
	if ok then
		_M.exist_indexes[collection] = true
		return ok , "OK"
	else
		return ok, err 
	end
end 

return _M