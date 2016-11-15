local tinycore = {}

tinycore.devices = {}
tinycore.plugins = {}
tinycore.config = {}

tinycore.actions = {}

local open = io.open
local json = require'json'

--helper
local function read_file(path)
    local file = open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

function tinycore.appendTableKey(tabl, keyName, value)
	if (tabl[keyName]) then
		table.insert(tabl[keyName], value)
	else
		tabl[keyName] = {value}
	end
end


function tinycore.load_config(filename)
	tinycore.config = json.decode(read_file(filename))
end

function tinycore.load_devices(config)
	if (config) then
		for i,v in ipairs(config.devices) do
			if _G[v.class] then
				tinycore.devices[v.id] = _G[v.class]:new(nil, v)
			else
				require("devices."..v.class)
				local device_defined = pcall(require, "devices."..v.class)
				if (device_defined) then
					tinycore.devices[v.id] = _G[v.class]:new(nil, v)
				end
			end
		end
	end
end

function tinycore.update_config_from_devices(config, devices)
	if (config and devices) then
		for i,v in ipairs(config.devices) do
			if (devices[v.id]) then
				config.devices[i].value = devices[v.id].props.value
			end
		end
	end
end

function tinycore.load_plugins(config)
	tinycore.plugins = {}
	if (config) then
		for i,v in ipairs(tinycore.config.plugins) do
			tinycore.plugins[v.plugin] = require("plugins."..v.plugin)
			tinycore.plugins[v.plugin].init(v)
		end
	end
end

-- Actions
function tinycore.runPlugin(actionName, actionParam)
	tinycore.appendTableKey(tinycore.actions, actionName, actionParam)
end

function tinycore.executeActions()
	local actionName, actionParams = next(tinycore.actions)
	while actionName ~= nil do
		tinycore.actions[actionName] = nil
		for pluginName, plugin in pairs(tinycore.plugins) do
			if (plugin[actionName]) then
				plugin[actionName](actionParams);
			end
		end
		actionName, actionParams = next(tinycore.actions)
	end
end

function tinycore.runDevice(actionName, actionParam, devices)
	local deviceList = devices
	local result = {}
	
	if (not deviceList) then
		deviceList = tinycore.devices
	end
	
	for i, device in pairs(deviceList) do
		if (device[actionName]) then
			result[device.props.id] = device[actionName](device, actionParam)
		end
	end
	return result
end

return tinycore