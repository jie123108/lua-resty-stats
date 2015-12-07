
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

function _M.ok(stats)
	if stats.status then
		local ok_count = 0
		for status, count in pairs(stats.status) do 
			status = tonumber(status) or 0
			if status >= 200 and status < 400 then
				ok_count = ok_count + tonumber(count)
			end
		end
		return ok_count
	else
		return '0'
	end
end

function _M.ok_alt(stats)
	if stats.status == nil then
		return ""
	end

	local status_all = {}
	for status, count in pairs(stats.status) do 
		local xstatus = tonumber(status) or 0
		if xstatus >= 200 and xstatus < 400 then
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


function _M.fail(stats)
	if stats.status then
		local fail_count = 0
		for status, count in pairs(stats.status) do 
			status = tonumber(status) or 0
			if status >= 400 then
				fail_count = fail_count + tonumber(count)
			end
		end
		return fail_count

	else
		return '0'
	end
end

function _M.fail_alt(stats)
	if stats.status == nil then
		return ""
	end

	local status_all = {}
	for status, count in pairs(stats.status) do 
		local xstatus = tonumber(status) or 0
		if xstatus >= 400 then
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