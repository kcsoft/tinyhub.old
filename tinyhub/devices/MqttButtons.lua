require'devices.GenericDevice'

MqttButtons = {props = {}}

function MqttButtons:new(o, opt)
	local self = GenericDevice:new(o, opt)
	self:extend(MqttButtons)
	self.props.value = ""
	return self
end

function MqttButtons:onMqttMessage(eventParam)
	self:onChangeProp({name = "value", value = eventParam.payload})
end

function MqttButtons:getMqttSubscribe(eventParam)
	local idx, buttons = next(self.props.buttons)
	local result = nil
	if (buttons.stateTopic) then
		result = {buttons.stateTopic}
	end
	return result
end

function MqttButtons:onWebChange(eventParam)
	local idx, buttons = next(self.props.buttons)
	local mqttMsg = {topic = buttons.topic, payload = buttons.message}
	tinycore.runPlugin("mqttPublish", mqttMsg)
	self:onMqttMessage({payload = self.props.value})
end

