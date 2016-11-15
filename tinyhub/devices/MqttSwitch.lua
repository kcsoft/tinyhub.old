require'devices.GenericDevice'

MqttSwitch = {props = {}}

function MqttSwitch:new(o, opt)
	local self = GenericDevice:new(o, opt)
	self:extend(MqttSwitch)
	self.props.value = 0
	return self
end

function MqttSwitch:onMqttMessage(eventParam)
	local value = 0
	if (eventParam.payload == self.props.onMessage) then
		value = 1
	end
	self:onChangeProp({name = "value", value = value})
end

function MqttSwitch:onWebChange(eventParam)
	local publishVal = self.props.offMessage
	if (eventParam == "1") then
		publishVal = self.props.onMessage
	end

	local mqttMsg = {topic = self.props.topic, payload = publishVal}
	tinycore.runPlugin("mqttPublish", mqttMsg)
	self:onMqttMessage({payload = publishVal})
end

function MqttSwitch:getMqttSubscribe(eventParam)
	if type(self.props.stateTopic) == "string" then
		return {self.props.stateTopic}
	else
		return self.props.stateTopic
	end
end