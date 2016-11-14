
define(['plugins/darksky/skycons.min', 'css!../../../styles/darksky'], function () {
	String.prototype.render = function() {
		var s = this;
		for (var i = 0; i < arguments.length; i++) {
			var regexp = new RegExp('\\{'+i+'\\}', 'gi');
			s = s.replace(regexp, arguments[i]);
		}
		return s;
	};

	function DarkskySensor(props, broadcast) {
		this.htmlTemplate = '<div id="{0}"></div>';
		this.htmlTemplateNow = '<div class="darksky-now"><span class="valign"></span><canvas id="{0}" width="64" height="64"></canvas><div class="darksky-text"> {1}{3} {2}</div></div>';
		this.htmlTemplateDaily = '<div class="darksky-daily"><span class="valign"></span><canvas id="{0}" width="56" height="56"></canvas><div class="darksky-text"><div class="darksky-date-temp"> {1} {2}{5} / {3}{5} </div><div> {4}</div></div></div>';
		this.props = props;
		this.broadcast = broadcast;
		this.dom = null;
	}

	DarkskySensor.prototype = {
		render: function() {
			return this.htmlTemplate.render(this.props.id);
		},

		afterRender: function() {
			this.dom = document.getElementById(this.props.id);
			if (this.props.value) {
				this.changed(this.props.value);
			}
		},

		changed: function(value) {
			var id, d, data = null, html = '', icons = {};
			var days = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
			try {
				data = JSON.parse(value);
			} catch(ex) {
				return;
			}
			if (data) {
				if (data.currently) {
					id = this.props.id+'-now';
					html += this.htmlTemplateNow.render(id, Math.round(data.currently.temperature), data.currently.summary, this.props.tempUnit);
					icons[id] = data.currently.icon;
				}
				if (data.daily && data.daily.data) {
					for (var i = 0; i <  data.daily.data.length; i++) {
						id = this.props.id+'-'+i;
						d = data.daily.data[i];
						var dailyDate = new Date(d.time*1000);
						dailyDate.setTime(dailyDate.getTime() - dailyDate.getTimezoneOffset()*60000);
						html += this.htmlTemplateDaily.render(id, days[dailyDate.getDay()].substring(0,3), Math.round(d.temperatureMax), Math.round(d.temperatureMin), d.summary, this.props.tempUnit);
						icons[id] = d.icon;
					}
				}
			}

			var skycons = new Skycons({"resizeClear": true});
			skycons.pause();
			this.dom.innerHTML = html;
			for (var i in icons) {
				skycons.add(i, icons[i]);
			}
			skycons.play();
		}
	};

	return {
		devices: {
			DarkskySensor: DarkskySensor
		}
	};
});