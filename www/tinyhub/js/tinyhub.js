
require.config({
	map: {
		'*': {'css': 'css.min'}
	}
});

var tinyhub = {
	server: 'ws://' + location.host + ':8080/',
	protocol: 'echo',
	websocket: null,
	connected: false,

	deviceModules: {},
	devices: [],

	needConfig: true,
	config: null,

	broadcastChange: function(change) {
		if (this.websocket.readyState == 1)
			this.websocket.send(JSON.stringify({changed: change}));
	},

	init: function() {
		this.connectWebsocket();
	},
	
	connectWebsocket: function() {
		this.websocket = new WebSocket(this.server, this.protocol);

		this.websocket.onopen = function() {
			this.onConnected();
		}.bind(this);

		this.websocket.onmessage = function(e) {
			this.onMessage(e);
		}.bind(this);

		this.websocket.onerror = function(e) {
			this.onError(e);
		}.bind(this);

		this.websocket.onclose = function(e) {
			setTimeout(function() {
				this.connectWebsocket();
			}.bind(this), 1000);
		}.bind(this);
	},

	onConnected: function() {
		this.connected = true;
		if (this.needConfig) {
			this.websocket.send(JSON.stringify({config: true}));
		}
	},

	onMessage: function(e) {
		var msg = null;
		try {
			msg = JSON.parse(e.data);
		} catch(ex) {
			return;
		}
		if (msg) {
			if (this.needConfig && typeof msg['config'] !== 'undefined') {
				this.needConfig = false
				this.config = msg['config'];
				this.onConfig();
			}
			if (typeof msg['changed'] !== 'undefined') {
				for (var i in msg['changed']) {
					if (this.devices[i]) {
						this.devices[i].changed(msg['changed'][i]);
					}
				}
			}
		}
	},

	onError: function(e) {
		console.log('Error:'+e.data);
	},

	onConfig: function() {
		var i, j, pluginModules = [];
		for (i = 0; i < this.config.plugins.length; i++) {
			if (this.config.plugins[i].js)
				pluginModules.push(this.config.plugins[i].js);
		}
		require(pluginModules, function() {
			for (i = 0; i < arguments.length; i++) {
				if (arguments[i].devices) {
					for (j in arguments[i].devices) {
						this.deviceModules[j] = arguments[i].devices[j];
					}
				}
			}
			this.onPluginsLoaded();
		}.bind(this));
	},
	
	onPluginsLoaded: function() {
		var html = '', tabs = '', pageHtml, i, j;

		this.devices = {};
		for (i = 0; i < this.config.devices.length; i++) {
			if (typeof this.deviceModules[this.config.devices[i]['class']] !== 'undefined') {
				this.devices[this.config.devices[i]['id']] = new this.deviceModules[this.config.devices[i]['class']](this.config.devices[i], function(arg) {
					this.broadcastChange(arg);
				}.bind(this));
			}
		}

		for (i = 0; i < this.config.pages.length; i++) {
			tabs += '<li class="tab-item page-'+this.config.pages[i].id+(i==0?' active':'')+'"><a href="javascript:tinyhub.selectTab(\''+this.config.pages[i].id+'\');">'+this.config.pages[i].name+'</a></li>';
			pageHtml = '';
			for (j = 0; j < this.config.pages[i].devices.length; j++) {
				if (typeof this.devices[this.config.pages[i].devices[j].deviceId] !== 'undefined')
					pageHtml += '<div class="th-row">' + this.devices[this.config.pages[i].devices[j].deviceId].render() + '</div>';
			}
			html += '<div class="page-'+this.config.pages[i].id+(i==0?' active':'')+'" id="page-'+this.config.pages[i].id+'">'+pageHtml+'</div>';
		}
		document.getElementById('tab-pages').innerHTML = tabs;
		document.getElementById('tab-content').innerHTML = html;

		for (i in this.devices) {
			this.devices[i].afterRender();
		}
	},

	selectTab: function(tabId) {
		var i, c, el = document.querySelectorAll('#tab-pages > .active, #tab-content > .active');
		for (i = 0; i < el.length; i++) {
			c = el[i].className;
			el[i].className = c.replace(new RegExp('(?:^|\\s)'+ 'active' + '(?:\\s|$)'), ' ');
		}
		el = document.querySelectorAll('#tab-pages > .page-'+tabId+', #tab-content > .page-'+tabId);
		for (i = 0; i < el.length; i++) {
			el[i].className += ' active';
		}
	}
};

tinyhub.init();
