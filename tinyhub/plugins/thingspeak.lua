local thingspeak = {}

tinycore = require("tinycore")
local http = require("ssl.https")

function thingspeak.init(plugin)
end

function thingspeak.onDeviceChange(params)
	for i, changes in ipairs(params) do
		for id, value in pairs(changes) do
			if tinycore.devices[id].props.thingspeak then
				local url = string.gsub(tinycore.devices[id].props.thingspeak, "\{value\}", value)
				http.request(url)
			end
		end
	end
end

return thingspeak