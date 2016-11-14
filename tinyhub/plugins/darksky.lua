local darksky = {}

require'uloop'
tinycore = require("tinycore")
local http = require("ssl.https")

function darksky.init(plugin)
	darksky.plugin = plugin
	darksky.timer = uloop.timer(darksky.onTimer, 5000)
end

function darksky.onTimer()
	local response = http.request(darksky.plugin.url)
	if (response) then
		tinycore.triggerEvent("onWeatherData", {name = "value", value = response}, nil)
	end
	darksky.timer:set(darksky.plugin.interval)
end


function darksky.onWeatherData(device, deviceResult)
end

darksky.actions = {
}

darksky.events = {
	onWeatherData = darksky.onWeatherData
}

return darksky