require'devices.Utils'

MqttButtons = {props = {}}

function MqttButtons:new(o, opt)
	o = o or {}
	o.props = Utils.deepCopy(opt)
	setmetatable(o, self)
	self.__index = self;
	self.props.value = 0
	return o
end

function MqttButtons:onMqttMessage(eventParam, actions)
	self.props.value = eventParam.payload
	
	local msg = {}
	msg[self.props.id] = self.props.value
	if (actions["webBroadcast"]) then
		table.insert(actions["webBroadcast"], msg)
	else
		actions["webBroadcast"] = {msg}
	end
end

function MqttButtons:onMqttSubscribe(eventParam, actions)
	local idx, buttons = next(self.props.buttons)
	local result = nil
	if (buttons.stateTopic) then
		result = {buttons.stateTopic}
	end
	return result
end

function MqttButtons:onWebChange(eventParam, actions)
	local idx, buttons = next(self.props.buttons)
	local mqttMsg = {topic = buttons.topic, payload = buttons.message}
	
	if (actions["mqttPublish"]) then
		table.insert(actions["mqttPublish"], mqttMsg)
	else
		actions["mqttPublish"] = {mqttMsg}
	end
	
	self:onMqttMessage({payload = self.props.value}, actions)
end

