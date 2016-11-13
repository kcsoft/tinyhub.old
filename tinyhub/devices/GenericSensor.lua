require'devices.GenericDevice'

GenericSensor = {props = {}}

function GenericSensor:new(o, opt)
	local self = GenericDevice:new(o, opt)
	self:extend(GenericSensor)
	self.props.value = ""
	return self
end
