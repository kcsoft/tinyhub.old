local mqtt = {}

tinycore = require("tinycore")

mqtt.subscribers = {}
mqtt.mqttClient = nil;

function mqtt.init(plugin)
	local result = tinycore.runDevice("getMqttSubscribe", nil, nil)
	for id, topics in pairs(result) do
		for i, topic in ipairs(topics) do
			tinycore.appendTableKey(mqtt.subscribers, topic, tinycore.devices[id])
		end
	end
	
	mosquitto = require("mosquitto")
	mqtt.mqttClient = mosquitto.new()
	
	mqtt.mqttClient.ON_CONNECT = function()
		print("mqtt connected")
		for k, v in pairs(mqtt.subscribers) do
			mqtt.mqttClient:subscribe(k)
		end
	end

	mqtt.mqttClient.ON_MESSAGE = function(mid, topic, payload)
		if (mqtt.subscribers[topic]) then
			tinycore.runDevice("onMqttMessage", {topic = topic, payload = payload}, mqtt.subscribers[topic])
			tinycore.executeActions()
		end
	end

	mqtt.mqttClient.ON_DISCONNECT = function()
		print("mqtt disconnected")
	end

	broker = nil
	if (plugin.broker) then
		broker = plugin.broker
	end
	mqtt.mqttClient:connect(broker)
	mqtt.mqttClient:loop_start()
end

function mqtt.mqttPublish(params)
	for i, param in ipairs(params) do
		mqtt.mqttClient:publish(param.topic, param.payload)
	end
end

return mqtt