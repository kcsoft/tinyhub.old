require'devices.GenericDevice'

MqttSensor = {props = {}}

function MqttSensor:new(o, opt)
	local self = GenericDevice:new(o, opt)
	self:extend(MqttSensor)
	self.props.value = ""
	return self
end

function MqttSensor:onMqttMessage(eventParam)
	self:onChangeProp({name = "value", value = eventParam.payload})
end

function MqttSensor:getMqttSubscribe(eventParam)
	local idx, attributes = next(self.props.attributes)
	return {attributes.topic}
end