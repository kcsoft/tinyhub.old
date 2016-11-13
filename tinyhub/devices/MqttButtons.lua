require'devices.GenericDevice'

MqttButtons = {props = {}}

function MqttButtons:new(o, opt)
	local self = GenericDevice:new(o, opt)
	self:extend(MqttButtons)
	self.props.value = ""
	return self
end

function MqttButtons:onMqttMessage(eventParam, actions)
	self:onChangeProp({name = "value", value = eventParam.payload}, actions)
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
	
	self:appendTableKey(actions, "mqttPublish", mqttMsg)
	self:onMqttMessage({payload = self.props.value}, actions)
end

