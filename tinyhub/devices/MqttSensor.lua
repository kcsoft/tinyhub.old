require'devices.Utils'

MqttSensor = {props = {}}

function MqttSensor:new(o, opt)
	o = o or {}
	o.props = Utils.deepCopy(opt)
	setmetatable(o, self)
	self.__index = self;
	self.props.value = ""
	return o
end

function MqttSensor:onMqttMessage(eventParam, actions)
	self.props.value = eventParam.payload
	
	local msg = {}
	msg[self.props.id] = self.props.value
	if (actions["webBroadcast"]) then
		table.insert(actions["webBroadcast"], msg)
	else
		actions["webBroadcast"] = {msg}
	end
end

function MqttSensor:onMqttSubscribe(eventParam, actions)
	local idx, attributes = next(self.props.attributes)
	return {attributes.topic}
end