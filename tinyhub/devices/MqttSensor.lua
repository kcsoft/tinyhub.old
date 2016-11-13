require'devices.GenericDevice'

MqttSensor = {props = {}}

function MqttSensor:new(o, opt)
	local self = GenericDevice:new(o, opt)
	self:extend(MqttSensor)
	self.props.value = ""
	return self
end

function MqttSensor:onMqttMessage(eventParam, actions)
	self:onChangeProp({name = "value", value = eventParam.payload}, actions)
end

function MqttSensor:onMqttSubscribe(eventParam, actions)
	local idx, attributes = next(self.props.attributes)
	return {attributes.topic}
end