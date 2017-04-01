
local _M = {}

local function sep(i)
	if i % 2 == 1 then
		return "  "
	else 
		return "\n"
	end
end

function _M.requests_alt(stats)
	if stats.hour_cnt == nil then
		return ""
	end

	local hours = {}
	for hour, count in pairs(stats.hour_cnt) do 
		table.insert(hours, hour)
	end
	table.sort(hours)
	local alts = {}
	for i, hour in ipairs(hours) do 
		table.insert(alts, hour .. ": " .. tostring(stats.hour_cnt[hour]))
		table.insert(alts, sep(i))
	end
	return table.concat(alts)
end

local function status_count(stats, begin, end_)
	if stats.status then
		local ok_count = 0
		for status, count in pairs(stats.status) do 
			status = tonumber(status) or 0
			if status >= begin and status <= end_ then
				ok_count = ok_count + tonumber(count)
			end
		end
		return ok_count
	else
		return '0'
	end
end

local function status_alt(stats, begin, end_)
	if stats.status == nil then
		return ""
	end

	local status_all = {}
	for status, count in pairs(stats.status) do 
		local xstatus = tonumber(status) or 0
		if xstatus >= begin and xstatus <= end_ then
			table.insert(status_all, status)
		end
	end

	table.sort(status_all)

	local alts = {}
	for i, status in ipairs(status_all) do 
		table.insert(alts, status .. ": " .. tostring(stats.status[status]))		
	end
	return table.concat(alts)
end

function _M.ok(stats)
	return status_count(stats, 200, 399)
end

function _M.ok_alt(stats)
	return status_alt(stats, 200, 399)
end

function _M.fail_4xx(stats)
	return status_count(stats, 400, 499)
end

function _M.fail_alt_4xx(stats)
	return status_alt(stats, 400, 499)
end

function _M.fail_5xx(stats)
	return status_count(stats, 500, 599)
end

function _M.fail_alt_5xx(stats)
	return status_alt(stats, 500, 599)
end

function _M.avgtime(stats)
	local req_time, count = stats.req_time, stats.count
	if req_time and count and count > 0 then
		local time_sum = req_time.all or 0
		return string.format("%.3f", time_sum/count)
	else
		return '0'
	end
end

function _M.avgtime_alt(stats)
	if stats.req_time == nil or stats.hour_cnt == nil then
		return ''
	end
	local hours = {}
	for hour, req_time in pairs(stats.req_time) do 
		if hour ~= "all" then
			table.insert(hours, tostring(hour))
		end
	end
	table.sort(hours)
	local alts = {}
	for i, hour in ipairs(hours) do 
		local count = stats.hour_cnt[hour] or 1
		local req_time = stats.req_time[hour] or 0
		table.insert(alts,  string.format("%s: %.3f", hour, req_time/count))
		table.insert(alts, sep(i))
	end
	return table.concat(alts)
end

return _M