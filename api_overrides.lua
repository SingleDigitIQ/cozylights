--mostly hacks to make sure that cozylights will be seen as air by other mods

local c_air = minetest.get_content_id("air")
local c_light1 = minetest.get_content_id("cozylights:light1")
local c_light14 = c_light1 + 13

local core_get_node = minetest.get_node
local core_get_node_or_nil = minetest.get_node_or_nil

cozylights.get_node = core_get_node

minetest.get_node = function(pos)
	local node = core_get_node(pos)
	if node and string.find(node.name, "cozylights:light", 1, true) then
		return { name = "air", param1 = node.param1, param2 = node.param2 }
	end
	return node
end

minetest.get_node_or_nil = function(pos)
	local node = core_get_node_or_nil(pos)
	if node and string.find(node.name, "cozylights:light", 1, true) then
		return { name = "air", param1 = node.param1, param2 = node.param2 }
	end
	return node
end

local core_get_node_raw = minetest.get_node_raw
if core_get_node_raw then
	cozylights.get_node_raw = core_get_node_raw
	minetest.get_node_raw = function(pos)
		local cid = core_get_node_raw(pos)
		if cid >= c_light1 and cid <= c_light14 then
			return c_air
		end
		return cid
	end
end

local core_find_nodes_in_area = minetest.find_nodes_in_area
cozylights.find_nodes_in_area = core_find_nodes_in_area

minetest.find_nodes_in_area = function(minp, maxp, nodenames)
	local search_air = false
	if type(nodenames) == "string" and nodenames == "air" then
		search_air = true
		nodenames = { "air" }
	elseif type(nodenames) == "table" then
		for _, name in ipairs(nodenames) do
			if name == "air" then
				search_air = true
				break
			end
		end
	end
	if search_air then
		local masked_names = {}
		if type(nodenames) == "table" then
			for k, v in pairs(nodenames) do
				masked_names[k] = v
			end
		end
		for i = 1, 14 do
			table.insert(masked_names, "cozylights:light" .. i)
		end
		nodenames = masked_names
	end
	return core_find_nodes_in_area(minp, maxp, nodenames)
end

local core_find_node_near = minetest.find_node_near
minetest.find_node_near = function(pos, radius, nodenames, search_center)
	local search_air = false
	if type(nodenames) == "string" and nodenames == "air" then
		search_air = true
		nodenames = { "air" }
	elseif type(nodenames) == "table" then
		for i = 1, #nodenames do
			if nodenames[i] == "air" then
				search_air = true
				break
			end
		end
	end
	if search_air then
		local masked_names = {}
		if type(nodenames) == "table" then
			for k, v in pairs(nodenames) do
				masked_names[k] = v
			end
		end
		for i = 1, 14 do
			masked_names[#masked_names + 1] = "cozylights:light" .. i
		end
		nodenames = masked_names
	end
	return core_find_node_near(pos, radius, nodenames, search_center)
end

local core_find_nodes_in_area_under_air = minetest.find_nodes_in_area_under_air
cozylights.find_nodes_in_area_under_air = core_find_nodes_in_area_under_air
local cozy_lights_names = {}
for i = 1, 14 do
	cozy_lights_names[i] = "cozylights:light" .. i
end

minetest.find_nodes_in_area_under_air = function(minp, maxp, nodenames)
	local results = core_find_nodes_in_area_under_air(minp, maxp, nodenames)
	local light_search_min = { x = minp.x, y = minp.y + 1, z = minp.z }
	local light_search_max = { x = maxp.x, y = maxp.y + 1, z = maxp.z }
	local light_nodes = minetest.find_nodes_in_area(light_search_min, light_search_max, cozy_lights_names)
	if #light_nodes > 0 then
		for i = 1, #light_nodes do
			local lpos = light_nodes[i]
			local target_pos = { x = lpos.x, y = lpos.y - 1, z = lpos.z }
			local node_under = minetest.get_node(target_pos)
			local name = node_under.name
			local matched = false
			if type(nodenames) == "string" then
				if string.sub(nodenames, 1, 6) == "group:" then
					matched = minetest.get_item_group(name, string.sub(nodenames, 7)) > 0
				else
					matched = (name == nodenames)
				end
			elseif type(nodenames) == "table" then
				for j = 1, #nodenames do
					local n = nodenames[j]
					if string.sub(n, 1, 6) == "group:" then
						if minetest.get_item_group(name, string.sub(n, 7)) > 0 then
							matched = true
							break
						end
					elseif name == n then
						matched = true
						break
					end
				end
			end
			if matched then
				results[#results + 1] = target_pos
			end
		end
	end
	return results
end

local function bulk_clear_cozylights(minp, maxp)
	local vm = cozylights.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local data = vm:get_data()
	local param2data = vm:get_param2_data()
	for i = 1, #data do
		local cid = data[i]
		if cid >= c_light1 and cid <= c_light14 then
			data[i] = c_air
			param2data[i] = 0
		end
	end
	vm:set_data(data)
	vm:set_param2_data(param2data)
	vm:write_to_map(false)
	return true
end

local core_place_schematic = minetest.place_schematic
minetest.place_schematic = function(pos, schematic, rotation, replacements, force_placement, flags)
	if not force_placement then
		local s_size = { x = 10, y = 25, z = 10 }
		if type(schematic) == "table" and schematic.size then
			s_size = schematic.size
		elseif type(schematic) == "string" then
			local schem_meta = minetest.read_schematic(schematic, { write_yslice_prob = "none" })
			if schem_meta and schem_meta.size then
				s_size = schem_meta.size
			end
		end
		local md = math.max(s_size.x, s_size.z)
		local minp = { x = pos.x - md, y = pos.y - 1, z = pos.z - md }
		local maxp = { x = pos.x + md, y = pos.y + s_size.y + 1, z = pos.z + md }
		local lights_present = minetest.find_nodes_in_area(minp, maxp, cozy_lights_names)
		if #lights_present > 0 then
			bulk_clear_cozylights(minp, maxp)
			cozylights:push_area_queue(minp, maxp, nil)
		end
	end
	return core_place_schematic(pos, schematic, rotation, replacements, force_placement, flags)
end

local core_spawn_tree = minetest.spawn_tree
minetest.spawn_tree = function(pos, treedef)
	local minp = { x = pos.x - 5, y = pos.y, z = pos.z - 5 }
	local maxp = { x = pos.x + 5, y = pos.y + 15, z = pos.z + 5 }
	local lights_present = minetest.find_nodes_in_area(minp, maxp, cozy_lights_names)
	if #lights_present > 0 then
		bulk_clear_cozylights(minp, maxp)
		cozylights:push_area_queue(minp, maxp, nil)
	end
	return core_spawn_tree(pos, treedef)
end

local core_gvm = minetest.get_voxel_manip
cozylights.get_voxel_manip = core_gvm
