
tinycore = require("tinycore")

tinycore.load_config("config.json")
tinycore.load_devices(tinycore.config)
tinycore.load_plugins(tinycore.config)

tinycore.plugins.websocket.loop()