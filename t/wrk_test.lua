--[[
test framework: https://github.com/wg/wrk
--]]

local random = {}
function random.choice(arr)
	return arr[math.random(1, #arr)]
end
function random.sample(str, len)
	local t= {}
	for i=1, len do
		local idx = math.random(#str)
		table.insert(t, string.sub(str, idx,idx))
	end
	return table.concat(t)
end

local urls = {
	"/byuri/",
	"/byarg",
	"/byarg/404?client_type=android",
	"/byuriarg",
	"/byhttpheaderin",
	"/byhttpheaderout"
}

function request()
	local url = random.choice(urls)
	local headers = nil
	if url == "/byuri/" then 
		url = url .. random.sample("ACKD952303LL", 4)
	elseif url == "/byarg" then 
		url = url .. "?client_type=" .. random.choice({"pc","ios","android", "web"})
	elseif url == "/byuriarg" then 
		url = url .. "?from=" .. random.choice({"partner","pc_cli","mobile_cli", "web_cli"})
	elseif url == "/byhttpheaderin" then 
		headers = {}
		headers.city = random.choice({"shanghai", "shengzheng","beijing"})
	elseif url == "/byhttpheaderout" then 
		url = url .. random.choice({"/hit", "/miss"})
	end

    wrk.method  = "GET"
    wrk.path    = url

    return wrk.format(nil, nil, headers)
end

