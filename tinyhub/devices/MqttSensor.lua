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
	Utils.appendTableKey(actions, "webBroadcast", msg)
end

function MqttSensor:onMqttSubscribe(eventParam, actions)
	local idx, attributes = next(self.props.attributes)
	return {attributes.topic}
end