local mqtt = {}

tinycore = require("tinycore")

mqtt.subscribers = {}
mqtt.mqttClient = nil;

function mqtt.init(plugin)
	tinycore.triggerEvent("onMqttSubscribe")
	
	mosquitto = require("mosquitto")
	mqtt.mqttClient = mosquitto.new()
	
	mqtt.mqttClient.ON_CONNECT = function()
		print("connected")
		for k, v in pairs(mqtt.subscribers) do
			mqtt.mqttClient:subscribe(k)
		end
	end

	mqtt.mqttClient.ON_MESSAGE = function(mid, topic, payload)
		if (mqtt.subscribers[topic]) then
			tinycore.triggerEvent("onMqttMessage", {topic = topic, payload = payload}, mqtt.subscribers[topic])
		end
	end

	mqtt.mqttClient.ON_DISCONNECT = function()
		print("disconnected")
	end

	broker = nil
	if (plugin.broker) then
		broker = plugin.broker
	end
	mqtt.mqttClient:connect(broker)
	mqtt.mqttClient:loop_start()
end

function mqtt.onMqttSubscribe(device, deviceResult)
	if (deviceResult) then
		for ti, tv in pairs(deviceResult) do
			if (mqtt.subscribers[tv]) then
				table.insert(mqtt.subscribers[tv], device)
			else
				mqtt.subscribers[tv] = {device}
			end
		end
	end
end

function mqtt.onMqttMessage(device, deviceResult)
end

function mqtt.publish(param)
	mqtt.mqttClient:publish(param.topic, param.payload)
end


mqtt.actions = {
	mqttPublish = mqtt.publish
}

mqtt.events = {
	onMqttSubscribe = mqtt.onMqttSubscribe,
	onMqttMessage = mqtt.onMqttMessage
}

return mqtt