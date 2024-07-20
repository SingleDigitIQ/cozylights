function cozylights:dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. cozylights:dump(v) .. ','
	   	end
	   	return s .. '} '
	else
		return tostring(o)
	end
end

function cozylights:finalize(table)
    return setmetatable({}, {
        __index = table,
        __newindex = nil
    })
end

function cozylights:prealloc(table, amount, default_val)
	for i = 1, amount do
		table[i] = default_val
	end
end

function cozylights:mod_loaded(str)
	if minetest.get_modpath(str) ~= nil then
		return true
	end
	return false
end

function cozylights:findIn(value,array)
	for i=1, #array do
		if array[i] == value then
			return true
		end
	end
	return false
end