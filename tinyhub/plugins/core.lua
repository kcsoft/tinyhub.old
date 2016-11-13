local core = {}

tinycore = require("tinycore")

function core.init(plugin)
end

function core.onChangeProp(device, deviceResult)
end

core.actions = {
}

core.events = {
	onChangeProp = core.onChangeProp
}

return core