-- Copyright (C) 2015 Xiaojie Liu (jie123108@163.com).
-- 
--[[
author: jie123108@163.com
date: 20151206
]]

local mongo = require("mongo")
local template = require "resty.template"
local cjson = require("cjson")
local stats = require("resty.stats")

local cache_tmpl = true 

local function create_option(collnames, table_name)
	local options = {}
	for _, collname in ipairs(collnames) do 
		local selected = ''
		if collname == table_name then
			selected = [[selected="selected"]]
		end
		table.insert(options, string.format([[<option value="%s" %s>%s</option>]], collname, selected, collname))
	end
	return table.concat(options,"\r\n")
end

local function get_all_table_info(table)
	local collnames = stats.get_stats_names()
	local options = create_option(collnames, table)
	return options
end

local function split(s, delimiter)
    local result = {};
    for match in string.gmatch(s, "[^"..delimiter.."]+") do
        table.insert(result, match);
    end
    return result;
end

local function add_day(date, n)
	local arr = split(date, "-")
	local year = 2015
	local month = 12
	local day = 12
	if #arr >= 1 then year = tostring(arr[1]) end
	if #arr >= 2 then month = tostring(arr[2]) end
	if #arr >= 3 then day = tostring(arr[3]) end
	local now = os.time({day=day,month=month,year=year})+n*3600*24
	return os.date("%Y-%m-%d", now)
end

local function get_query_date(args)
	local date = args.date 
	if date == nil or date == 'today' then
		date = string.sub(ngx.localtime(), 1, 10)
	end
	local prev_day = add_day(date, -1)
	local next_day = add_day(date, 1)
	local today = string.sub(ngx.localtime(), 1, 10)
	return date, prev_day, next_day, today
end

local function stats_api()
	local args, err = ngx.req.get_uri_args()
	local table = args.table
	local key = args.key
	local limit = tonumber(args.limit) or 300
	local date = args.date 
	if date == 'today' then
		date = string.sub(ngx.localtime(), 1, 10)
	end

	local stats_list = {}
	local ok = nil
	local errmsg = nil
	local mongo_cfg = stats.mongo_cfg
	-- query stats
	if not table then
		errmsg = "args 'table' missing"
	elseif key then
		ok, stats_list = mongo.get_stats_by_key(mongo_cfg, table, key, limit)
		if not ok then
			ngx.log(ngx.ERR, "mongo.get_stats_by_key(", table, ",", key, ") failed! err:", tostring(stats_list))
			errmsg = "error on query:" .. tostring(stats_list)
			stats_list = {}
		end
	else
		ok, stats_list = mongo.get_stats(mongo_cfg, table, date, nil, limit)
		if not ok then
			ngx.log(ngx.ERR, "mongo.get_stats(", table, ",", date, ") failed! err:", tostring(stats_list))
			errmsg = "error on query:" .. tostring(stats_list)
			stats_list = {}
		end
	end
	local resp = {
		errmsg=errmsg,
		stats=stats_list,
	}
	ngx.header["Content-Type"] = "application/json; charset=utf-8"
	ngx.say(cjson.encode(resp))
end

local function stats_def()
	local args, err = ngx.req.get_uri_args()
	local table = args.table
	local key_pattern = args.key
	local tables = get_all_table_info(table)
	local diff = args.diff or true-- get requests diff of pre day and current date
	local date, prev_day, next_day, today = get_query_date(args)

	if diff == "false" then 
		diff = false
	end
	args.submit = nil
	args.date = prev_day
	local prev_uri = ngx.var.uri .. "?" .. ngx.encode_args(args)
	args.date = next_day
	local next_uri = ngx.var.uri .. "?" .. ngx.encode_args(args)
	args.date = today
	local today_uri = ngx.var.uri .. "?" .. ngx.encode_args(args)


	local stats_list = {}
	local errmsg = nil
	-- query stats
	if table and date then
		local mongo_cfg = stats.mongo_cfg
		local ok, stats = mongo.get_stats(mongo_cfg, table, date, key_pattern, 300)
		if not ok then
			ngx.log(ngx.ERR, "mongo.get_stats(", table, ",", date, ") failed! err:", tostring(stats))
			errmsg = "error on query:" .. tostring(stats)
		else
			stats_list = stats
			if diff then 
				local ok, pre_stats = mongo.get_stats(mongo_cfg, table, prev_day, key_pattern, 400)
				if ok then 
					local pre_counts = {}
					for _, stats in ipairs(pre_stats) do 
						if stats.key then 
							pre_counts[stats.key] = stats.count
						end
					end
					for _, stats in ipairs(stats_list) do 
						local pre_count = 0
						if stats.key then 
							pre_count = pre_counts[stats.key] or 0
						end
						stats.pre_count = pre_count
					end
				end
			end
		end
	end
	
	local page_args = {tables=tables, 
					uri=ngx.var.uri, mon=args.mon,
					table=table, date=date, key=key_pattern,
					prev_uri=prev_uri, next_uri=next_uri, today_uri=today_uri,
					errmsg=errmsg, prev_day=prev_day}

	ngx.log(ngx.INFO, "page_args: ", cjson.encode(page_args))
	page_args.stats_list = stats_list

	template.caching(cache_tmpl or true)
	template.render("stats.html", page_args)
end

local function stats_key()
	local args, err = ngx.req.get_uri_args()
	local key = args.key
	local table = args.table
	local limit = tonumber(args.limit)

	local stats_list = {}
	local errmsg = nil
	-- query stats
	if key then
		local mongo_cfg = stats.mongo_cfg
		local ok, stats = mongo.get_stats_by_key(mongo_cfg, table, key)
		if not ok then
			ngx.log(ngx.ERR, "mongo.get_stats_by_key(", table, ",", key, ") failed! err:", tostring(stats))
			errmsg = "error on query:" .. tostring(stats)
		else
			stats_list = stats
		end
	end
	
	local page_args = {
					key=key, limit=limit, 
					errmsg=errmsg}
	ngx.log(ngx.INFO, "page_args: ", cjson.encode(page_args))
	page_args.stats_list = stats_list
	
	template.caching(cache_tmpl or true)
	template.render("stats_key.html", page_args)
end

ngx.header["Content-Type"] = 'text/html'

local uri = ngx.var.uri
local router = {
	["/stats"] = stats_def,
	["/stats/api"] = stats_api,
	["/stats/key"] = stats_key,
}

local func = router[uri]
if func then 
	func()	
else 
	ngx.log(ngx.ERR, "invalid request [", uri, "]")
	ngx.exit(404)
end
