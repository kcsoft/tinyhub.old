local tinycore = {}

tinycore.devices = {}
tinycore.plugins = {}
tinycore.config = {}

tinycore.actions = {}
tinycore.events = {}

local open = io.open
local json = require'json'


local function read_file(path)
    local file = open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
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
			for k, a in pairs(tinycore.plugins[v.plugin].actions) do
				tinycore.actions[k] = a
			end
			for k, a in pairs(tinycore.plugins[v.plugin].events) do
				tinycore.events[k] = a
			end
			tinycore.plugins[v.plugin].init(v)
		end
	end
end

-- Events and Actions
function tinycore.executeActions(actions)
	for actionName, action in pairs(actions) do
		for i, data in ipairs(action) do
			tinycore.actions[actionName](data);
		end
	end
end

function tinycore.triggerEvent(eventName, eventParam, devices)
	local actions = {}
	local eventDevices = devices
	
	if (not eventDevices) then
		eventDevices = tinycore.devices
	end
	
	for i, d in pairs(eventDevices) do
		if (d[eventName]) then
			tinycore.events[eventName](d, d[eventName](d, eventParam, actions))
		end
	end
	tinycore.executeActions(actions)
end

return tinycore