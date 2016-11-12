
require("uloop")
tinycore = require("tinycore")

uloop.init()

tinycore.load_config("config.json")
tinycore.load_devices(tinycore.config)
tinycore.load_plugins(tinycore.config)

uloop.run()