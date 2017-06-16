# tinyhub


Open source home automation software for OpenWRT written in Lua.

## Required packages

* mosquitto-nossl (optional)
* lua
* lua-mosquitto
* luabitop
* libubox-lua
* luasocket
* lua-coxpcall
* luasec


## Installation
Copy `www/tinyhub` to OpenWRT `/www` folder.  
Copy `tinyhub` to OpenWRT. e.g. `/usr/local`  
Copy `config.json.example` to `config.json`. Edit the `config.json` file to configure plugins, devices, pages.  
Create your startup script in `/etc/init.d` to run `lua tinyhub.lua` so that tinyhub starts on boot and also you can start/stop from LuCI.  
Open `http://<openwrt>/tinyhub/` in your browser.  


## Plugins
* Core (core)
* Websocket (core)
* Mqtt
* UBus
* Presence (detect router connected clients)
* Darksky (weather)


## Devices
* GenericDevice (base device, provides device change event, run actions set in device `onChange` property)
* GenericSensor
* MqttButtons
* MqttSwitch
* MqttSensor
* DarkskySensor (display weather data)

