require'devices.Utils'

MqttSwitch = {props = {}}

function MqttSwitch:new(o, opt)
	o = o or {}
	o.props = Utils.deepCopy(opt)
	setmetatable(o, self)
	self.__index = self;
	self.props.value = 0
	return o
end

function MqttSwitch:onMqttMessage(eventParam, actions)
	if (eventParam.payload == "1") then
		self.props.value = 1
	else
		self.props.value = 0
	end
	
	local msg = {}
	msg[self.props.id] = self.props.value
	Utils.appendTableKey(actions, "webBroadcast", msg)
end

function MqttSwitch:onWebChange(eventParam, actions)
	local publishVal
	if (eventParam == "1") then
		self.props.value = 1
		publishVal = self.props.onMessage
	else
		self.props.value = 0
		publishVal = self.props.offMessage
	end

	local mqttMsg = {topic = self.props.topic, payload = publishVal}
	Utils.appendTableKey(actions, "mqttPublish", mqttMsg)
	self:onMqttMessage({payload = publishVal}, actions)
end

function MqttSwitch:onMqttSubscribe(eventParam, actions)
	if type(self.props.stateTopic) == "string" then
		return {self.props.stateTopic}
	else
		return self.props.stateTopic
	end
end