-- Copyright (C) 2015 Xiaojie Liu (jie123108@163.com).
-- 
--[[
author: jie123108@163.com
date: 20151206
]]

local _M = {}

_M.servers = {
	["localnginx"]={host="127.0.0.1", port=27017, dbname="ngx_stats"},
	--MyStats={host="192.168.1.200", port=27017, dbname="ngx_stats"},
}

_M.cache_tmpl = true

return _M