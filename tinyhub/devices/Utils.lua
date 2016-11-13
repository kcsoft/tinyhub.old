Utils = {}

function Utils.merge(a, b)
    for k, v in pairs(b) do
        if (type(v) == "table") and (type(a[k] or false) == "table") then
            Utils.merge(a[k], b[k])
        else
            a[k] = v
        end
    end
    return a
end

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
