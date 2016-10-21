String.prototype.format = function() {
	var string = this;
	for (var i = 0; i < arguments.length; i++) {
		var regexp = new RegExp('\\{'+i+'\\}', 'gi');
		string = string.replace(regexp, arguments[i]);
	}
	return string;
};

function MqttSwitch(props, broadcast) {
	this.htmlTemplate = '<label class="form-switch"><input type="checkbox" id="{0}"/><i class="form-icon"></i>{1}</label>';
	this.props = props;
	this.broadcast = broadcast;
	this.dom = null;
}

MqttSwitch.prototype = {
	render: function() {
		return this.htmlTemplate.format(this.props.id, this.props.name);
	},

	afterRender: function() {
		this.dom = document.getElementById(this.props.id);
		if (this.props.value) {
			this.changed(this.props.value);
		}
		this.dom.addEventListener('change', function(e) {
			this.onChange(e);
		}.bind(this));
	},

	onChange: function(e) {
		var v = this.dom.checked?this.props.onMessage:this.props.offMessage;
		var data = {};
		data[this.props.id] = v;
		this.broadcast(data);
	},

	changed: function(value) {
		this.dom.checked = (value == this.props.onMessage);
	}
};

function MqttSensor(props, broadcast) {
	this.htmlTemplate = '<div class="pull-right" id="{0}"/></div><div>{1}</div>';
	this.props = props;
	this.broadcast = broadcast;
	this.dom = null;
}

MqttSensor.prototype = {
	render: function() {
		return this.htmlTemplate.format(this.props.id, this.props.name);
	},

	afterRender: function() {
		this.dom = document.getElementById(this.props.id);
		if (this.props.value) {
			this.changed(this.props.value);
		}
	},

	changed: function(value) {
		if (this.props.attributes[0].messageMap && this.props.attributes[0].messageMap[value])
			value = this.props.attributes[0].messageMap[value];
		if (this.props.attributes[0].unit)
			value += this.props.attributes[0].unit;
		this.dom.innerHTML = value;
	}
};

function MqttButtons(props, broadcast) {
	this.htmlTemplate = '<button class="btn pull-right" id="{0}"/>{2}</button><div>{1}</div>';
	this.props = props;
	this.broadcast = broadcast;
	this.dom = null;
}

MqttButtons.prototype = {
	render: function() {
		return this.htmlTemplate.format(this.props.id, this.props.name, this.props.buttons[0].text);
	},

	afterRender: function() {
		this.dom = document.getElementById(this.props.id);
		this.dom.addEventListener('click', function(e) {
			this.onChange(e);
		}.bind(this));
	},

	onChange: function(e) {
		var data = {};
		data[this.props.id] = 1;
		this.broadcast(data);
	},

	changed: function(value) {
	}
};
