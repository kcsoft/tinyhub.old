# tinyhub


Open source home automation software for OpenWRT written in Lua.

##Required packages

* mosquitto-nossl (optional)
* lua
* lua-mosquitto
* luabitop
* lua-copas
* luasocket
* lua-coxpcall
* luasec


##Installation
Copy `www/tinyhub` to OpenWRT `/www` folder.  
Copy `tinyhub` to OpenWRT. e.g. `/usr/local`  
Edit the `config.json` file to configure plugins, devices, pages.  
Create your startup script in `/etc/init.d` to run `lua tinyhub.lua` so that tinyhub starts on boot and also you can start/stop from LuCI.  
Open `http://<openwrt>/tinyhub/` in your browser.  


##Plugins
* Websocket (core)
* Mqtt


##Devices
* MqttButtons
* MqttSwitch
* MqttSensor
