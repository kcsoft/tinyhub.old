local tinyubus = {}

require("ubus")
tinycore = require("tinycore")

tinyubus.connection = nil
tinyubus.ubus_objects = {tinyhub = {}}

function tinyubus.init()
	tinyubus.connection = ubus.connect()
	if not tinyubus.connection then
		print("Failed to connect to ubus")
	else
		for pluginname, plugin in pairs(tinycore.plugins) do
			for actionname, action in pairs(plugin.actions) do
				tinyubus.ubus_objects.tinyhub[actionname] = {function (req, param) action(param) end, {param = ubus.STRING }}
			end
		end
		tinyubus.connection:add(tinyubus.ubus_objects)
	end
end

tinyubus.actions = {
}

tinyubus.events = {
}

return tinyubus