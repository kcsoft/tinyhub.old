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
	if (actions["webBroadcast"]) then
		table.insert(actions["webBroadcast"], msg)
	else
		actions["webBroadcast"] = {msg}
	end
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
	if (actions["mqttPublish"]) then
		table.insert(actions["mqttPublish"], mqttMsg)
	else
		actions["mqttPublish"] = {mqttMsg}
	end
	
	self:onMqttMessage({payload = publishVal}, actions)
end

function MqttSwitch:onMqttSubscribe(eventParam, actions)
	return {self.props.stateTopic}
end