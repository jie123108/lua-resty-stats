--[[
author: jie123108@163.com
date: 20151120
]]
local mongo = require "resty.mongol"
local t_ordered = require("resty.stats.orderedtable")
local _M = {}

local function t_concat(t, seq)
    seq = seq or ""
    if type(t) ~= 'table' then
        return tostring(t)
    end
    if #t > 0 then
        return table.concat(t, seq)
    end 
    local keys = {}
    for k, v in pairs(t) do 
        table.insert(keys, k .. "_" .. v)
    end
    return table.concat(keys, seq)
end


_M.init_seed = function ()
    local cur_time =  ngx.time()
    math.randomseed(cur_time)
end

local mt = { __index = _M }

function _M:new(mongo_cfg, collname)	
    assert(type(mongo_cfg) == 'table', "mongo_cfg must be a table")
	local dbname = mongo_cfg.dbname
	local timeout = mongo_cfg.timeout or 1000*5
    mongo_cfg.timeout = timeout
    collname = collname or "test"
	
    local ns = dbname .. "." .. collname
    return setmetatable({ mongo_cfg = mongo_cfg, dbname=dbname, collname=collname, ns=ns}, mt)
end

function _M:init()
    if self.conn then
        return true
    end
	local host = self.mongo_cfg.host
	local port = self.mongo_cfg.port
	local conn = mongo:new()
    conn:set_timeout(self.mongo_cfg.timeout) 
    local ok, err = conn:connect(host, port)
    if not ok then
        ngx.log(ngx.ERR, "connect to mongodb (", host, ":", port, ") failed! err:", tostring(err))
        return ok, err
    end

    local db = conn:new_db_handle(self.dbname)
    local coll = db:get_col(self.collname)

    -- TODO: auth..
    --r = db:auth("admin", "admin")
    self.conn = conn
    self.db = db
    self.coll = coll

	return true
end


function _M:uninit()
	if self.conn then
		local pool_timeout = self.mongo_cfg.pool_timeout or 1000 * 60
		local pool_size = self.mongo_cfg.pool_size or 30
		self.conn:set_keepalive(pool_timeout, pool_size)
		self.conn = nil
		self.db = nil
		self.coll = nil
	end
end

function _M:update(selector, update, upsert, multiupdate, safe)    
	if self.coll == nil then
		return false, "init failed!"
	end
	return self.coll:update(selector, update, upsert, multiupdate, safe)
end

function _M:insert(obj, continue_on_error, safe)
    local ok, err = self:init()
	if not ok then
		return false, err
	end
	if type(obj) == 'table' and #obj < 1 then
		obj = {obj}
	end

    local ok, ret, err = pcall(self.coll.insert, self.coll, obj, continue_on_error, safe)
    self:uninit()
    if ok then
        return ret, err 
    else
        return ok, ret
    end
    --return self.coll:insert(obj, continue_on_error, safe)
end

function _M:upsert(selector, update)
    local ok, err = self:init()
    if not ok then
        return false, err
    end
    -- update(selector, update, upsert, multiupdate, safe)
    local ok, ret, err = pcall(self.coll.update,self.coll, selector, update, 1, 0, 0)
    self:uninit()
    if ok then
        return ret, err 
    else
        return ok, ret
    end
    --return self.coll:update(selector, update, 1, 0, 0)
end

-- For parameter types and descriptions, reference：https://docs.mongodb.org/manual/reference/method/db.collection.createIndex/#db.collection.createIndex
function _M:ensure_index(keys, options, collname)
    local ok, err = self:init()
    if not ok then
        return false, err
    end
	options = options or {}

    local index = t_ordered({})
    local _keys = t_ordered():merge(keys)
    index.key = _keys
    index.name = options.name or t_concat(_keys,'_')
    for i,v in ipairs({"unique","background", "sparse"}) do
        if options[v] ~= nil then
            index[v] = options[v] and true or false
        end
    end

    local doc = t_ordered()
    -- used $cmd: https://www.bookstack.cn/read/mongodb-4.2-manual/662e17e4e7c25f48.md#dbcmd.createIndexes
    doc:merge({createIndexes = collname})
    doc:merge({indexes = {index}})

    local retinfo, errmsg = self.db:cmd(doc)

    self:uninit()
    local ok = false
    if retinfo then
        ok = retinfo.ok == 1
    end

    return ok, errmsg, index.name
end

return _M