local cron = {}

require'uloop'
tinycore = require("tinycore")

function cron.init(plugin)
	cron.plugin = plugin
	cron.timer = uloop.timer(cron.onTimer, 5000)
end

function cron.onTimer()
	for actionName, actionParam in pairs(cron.plugin.actions) do
		tinycore.runPlugin(actionName, actionParam)
	end
	tinycore.executeActions()
	cron.timer:set(cron.plugin.interval)
end

return cron