Utils = {}

function Utils.shallowCopy(orig)
   local orig_type, copy = type(orig), nil
   if orig_type == "table" then
	  copy = {}
	  for orig_key, orig_value in ipairs(orig) do
		 copy[orig_key] = orig_value
	  end
   else copy = orig end
   return copy
end

function Utils.deepCopy(orig)
   local orig_type, copy = type(orig), nil
   if orig_type == "table" then
	  copy = {}
	  for orig_key, orig_value in next, orig, nil do
		 copy[Utils.deepCopy(orig_key)] = Utils.deepCopy(orig_value)
	  end
	  setmetatable(copy, Utils.deepCopy(getmetatable(orig)))
   else copy = orig end
   return copy
end

function Utils.appendTableKey(tabl, keyName, value)
	if (tabl[keyName]) then
		table.insert(tabl[keyName], value)
	else
		tabl[keyName] = {value}
	end
end