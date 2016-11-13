
define(function () {
	String.prototype.render = function() {
		var s = this;
		for (var i = 0; i < arguments.length; i++) {
			var regexp = new RegExp('\\{'+i+'\\}', 'gi');
			s = s.replace(regexp, arguments[i]);
		}
		return s;
	};
	
	function GenericSensor(props, broadcast) {
		this.htmlTemplate = '<div class="pull-right" id="{0}"/></div><div>{1}</div>';
		this.props = props;
		this.broadcast = broadcast;
		this.dom = null;
	}

	GenericSensor.prototype = {
		render: function() {
			return this.htmlTemplate.render(this.props.id, this.props.name);
		},

		afterRender: function() {
			this.dom = document.getElementById(this.props.id);
			if (this.props.value) {
				this.changed(this.props.value);
			}
		},

		changed: function(value) {
			this.dom.innerHTML = value;
		}
	};

	return {
		devices: {
			GenericSensor: GenericSensor
		}
	}
});