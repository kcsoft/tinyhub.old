require'devices.Utils'

GenericDevice = {props = {}}

function GenericDevice:new(o, opt)
	o = o or {}
	o.props = Utils.deepCopy(opt)
	setmetatable(o, self)
	self.__index = self;
	return o
end

function GenericDevice:extend(b)
	for k, v in pairs(b) do
		if (type(v) == "table") and (type(self[k] or false) == "table") then
			Utils.merge(self[k], b[k])
		else
			self[k] = v
		end
	end
	return self
end

function GenericDevice:appendTableKey(tabl, keyName, value)
	if (tabl[keyName]) then
		table.insert(tabl[keyName], value)
	else
		tabl[keyName] = {value}
	end
end

function GenericDevice:onChangeProp(eventParam, actions)
	local oldValue = self.props[eventParam.name]
	self.props[eventParam.name] = eventParam.value
	if self.props[eventParam.name] ~= oldValue then
		local msg = {}
		msg[self.props.id] = self.props[eventParam.name]
		self:appendTableKey(actions, "webBroadcast", msg)

		if self.props.onChange then
			if self.props.onChange.to == eventParam.value then
				for actionName, actionParam in pairs(self.props.onChange.actions) do
					self:appendTableKey(actions, actionName, actionParam)
				end
			end
		end
	end
end
