local core = {}

tinycore = require("tinycore")

function core.init(plugin)
end

function core.onDeviceChange(params)
	for i, changes in ipairs(params) do
		for id, value in pairs(changes) do
			if tinycore.devices[id].props.onChange then
				if tinycore.devices[id].props.onChange.to == value then
					for actionName, actionParam in pairs(tinycore.devices[id].props.onChange.actions) do
						tinycore.runPlugin(actionName, actionParam)
					end
				end
			end
		end
	end
end

return core