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
		tinycore.runDevice("onWeatherData", {name = "value", value = response}, nil)
		tinycore.executeActions()
	end
	darksky.timer:set(darksky.plugin.interval)
end

return darksky