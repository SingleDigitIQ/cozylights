local mf = math.floor
local hash_pos = cozylights.hash_pos

function cozylights:show_brush_settings(player_name, itemstack)
	local lb = cozylights:get_brush_settings(itemstack, player_name)
	local settings_formspec = {
		"formspec_version[4]",
		"size[5.2,5]",
		"label[1.45,0.5;Light Brush Settings]",

		"label[0.95,1.35;Radius]",
		"field[3.6,1.1;0.7,0.5;radius;;" .. lb.radius .. "]",
		"tooltip[0.95,1.1;3.4,0.5;If radius is 0 then only one node will be affected by the brush.\nIf not zero then it's a sphere of affected nodes with specified radius.\nAs of now max radius is only 120.\nWith radiuses over 30 mouse hold as of now does not work, only point and click]",

		"label[0.95,2.05;Brightness]",
		"field[3.6,1.8;0.7,0.5;brightness;;" .. lb.brightness .. "]",
		"tooltip[0.95,1.8;3.4,0.5;Brightness - for most brush modes values are from 1 to 14, corresponding to engine light levels.\nIf brush mode is 'darken' or 'override' then 0 will replace lowest light levels with air.]",

		"label[0.95,2.75;Strength]",
		"field[3.6,2.5;0.7,0.5;strength;;" .. lb.strength .. "]",
		"tooltip[0.95,2.5;3.4,0.5;Strength, can be from 0 to 1, decimal values of any precision are valid.\nDetermines how bright(relative to brightness setting) light nodes in affected area will be.]",

		"label[0.95,3.45;Brush Mode]",
		"dropdown[2.8,3.2;1.5,0.5;mode;default,erase,override,lighten,darken,blend;" .. lb.mode .. "]",
		"tooltip[0.95,3.2;3.4,0.5;\nDefault - replace only dimmer light nodes or air with brush.\n\nErase - inverse of default, replaces only lighter nodes with darker nodes or air if brightness is 0.\n\nOverride - set light nodes as brush settings dictate regardless of difference in brigthness.\n\nLighten - milder than default mode.\n\nDarken - milder erase, does not darken below light 1(does not replace with air).\n\nBlend - blend affected nodes' brigthness with brush brigthness.\nEven though behaves correctly, as of now looks weird and unintuitive if radius is not 0.]",
		"button_exit[1.1,4;3,0.8;confirm;Confirm]",
	}
	minetest.show_formspec(player_name, "cozylights:brush_settings", table.concat(settings_formspec, ""))
end

minetest.register_tool("cozylights:light_brush", {
	description = "Light Brush",
	inventory_image = "light_brush.png",
	wield_image = "light_brush.png^[transformR90",
	tool_capabilities = {
		full_punch_interval = 0.3,
		max_drop_level = 1,
	},
	range = 100.0,
	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.under then
			local nodenameunder = cozylights.get_node(pointed_thing.under).name
			local nodedefunder = minetest.registered_nodes[nodenameunder]
			local name = user:get_player_name()
			local lb = cozylights:get_brush_settings(itemstack, name)
			local above = pointed_thing.above
			if nodenameunder ~= "air" and nodedefunder.buildable_to == true then
				above.y = above.y - 1
			end
			local cp = cozylights.cozyplayers[name]
			local above_hash = hash_pos(above)
			if cp then
				cp.last_brush_hash = above_hash
			end
			cozylights:draw_brush_light(pointed_thing.above, lb)
		end
		return itemstack
	end,
	on_place = function(itemstack, placer, pointed_thing)
		local name = placer:get_player_name()
		if cozylights:undo_last_brush(name) then
			minetest.chat_send_player(name, "Light map reverted.")
		else
			minetest.chat_send_player(name, "Brush history is empty.")
		end
		return itemstack
	end,
	on_secondary_use = function(itemstack, user, pointed_thing)
		local name = user:get_player_name()
		if cozylights:undo_last_brush(name) then
			minetest.chat_send_player(name, "Light map reverted.")
		else
			minetest.chat_send_player(name, "Brush history is empty.")
		end
		return itemstack
	end,
	sound = { breaks = "default_tool_breaks" },
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "cozylights:brush_settings" or not player then
		return
	end
	local itemstack = player:get_wielded_item()
	if itemstack:get_name() ~= "cozylights:light_brush" then
		minetest.chat_send_player(player:get_player_name(), "Settings closed: tool context lost.")
		return
	end
	local meta = itemstack:get_meta()
	local updated = false
	if fields.brightness then
		meta:set_int("brightness", math.min(14, math.max(0, tonumber(fields.brightness) or 0)))
		updated = true
	end
	if fields.radius then
		meta:set_int("radius", math.min(200, math.max(0, tonumber(fields.radius) or 0)))
		updated = true
	end
	if fields.strength then
		meta:set_float("strength", math.max(0, math.min(1, tonumber(fields.strength) or 0)))
		updated = true
	end
	if fields.mode then
		local mode_map = { default = 1, erase = 2, override = 3, lighten = 4, darken = 5, blend = 6 }
		meta:set_int("mode", mode_map[fields.mode] or 1)
		updated = true
	end
	if updated then
		local mode_names = { "Default", "Erase", "Override", "Lighten", "Darken", "Blend" }
		local mode_idx = meta:get_int("mode")
		local desc = string.format(
			"Light Brush\nRadius: %d | Brightness: %d\nStrength: %.2f | Mode: %s",
			meta:get_int("radius"),
			meta:get_int("brightness"),
			meta:get_float("strength"),
			mode_names[mode_idx] or "Default"
		)
		meta:set_string("description", desc)
		local tints = {
			[1] = "",
			[2] = "^[colorize:#FF0000:60",
			[3] = "^[colorize:#00FF00:60",
			[4] = "^[colorize:#00FFFF:60",
			[5] = "^[colorize:#000000:80",
			[6] = "^[colorize:#FF00FF:60",
		}
		local base_img = minetest.registered_tools["cozylights:light_brush"].inventory_image
		local wield_base = minetest.registered_tools["cozylights:light_brush"].wield_image
		meta:set_string("inventory_image", base_img .. tints[mode_idx])
		meta:set_string("wield_image", base_img .. tints[mode_idx] .. "^[transformR90")
		player:set_wielded_item(itemstack)
		local cp = cozylights.cozyplayers[player:get_player_name()]
		if cp and cp.hud_active then
			cozylights:update_wield_hud(player, cp, itemstack, 2)
		end
	end
end)

local function calc_dims_for_brush(brightness, radius, strength, even)
	local dim_levels = {}
	--- this gradient attempts to get more colors, but that looks like a super weird monochrome rainbow and immersion braking
	--strength = (strength+0.05)*2
	--
	--local current_brightness = brightness
	--local step = math.sqrt(radius/brightness)
	--local initial_step = step
	--for i = 1, radius do
	--	dim_levels[i] = current_brightness
	--	if i>step then
	--		step = step*strength + math.sqrt(i)
	--		current_brightness = current_brightness - 1
	--	end
	--end
	--- this gradient drops brightness fast but spreads dimmer lights over farther
	if strength == 1 then
		even = true
	end
	strength = strength * 5
	dim_levels[1] = brightness
	if even ~= true then
		for i = 2, radius do
			local dim = math.sqrt(math.sqrt(i)) * (6 - strength)
			local light_i = mf(brightness - dim)
			if light_i > 0 then
				if light_i < 15 then
					dim_levels[i] = light_i
				else
					dim_levels[i] = 14
				end
			else
				dim_levels[i] = 1
			end
		end
	else
		for i = 2, radius do
			dim_levels[i] = brightness
		end
	end
	return dim_levels
end

local c_air = minetest.get_content_id("air")
local c_light1 = minetest.get_content_id("cozylights:light1")
local c_lights = {
	c_light1,
	c_light1 + 1,
	c_light1 + 2,
	c_light1 + 3,
	c_light1 + 4,
	c_light1 + 5,
	c_light1 + 6,
	c_light1 + 7,
	c_light1 + 8,
	c_light1 + 9,
	c_light1 + 10,
	c_light1 + 11,
	c_light1 + 12,
	c_light1 + 13,
}
local gent_total = 0
local gent_count = 0

local function draw_one_node(pos, lb)
	local node = cozylights.get_node(pos)
	local brightness = lb.brightness
	local new_node_name = "cozylights:light" .. brightness
	if brightness == 0 then
		new_node_name = "air"
	end
	if node.name == "air" and new_node_name ~= node.name then
		minetest.set_node(pos, {
			name = new_node_name,
			param2 = brightness,
		})
		return
	end
	if string.find(node.name, "cozylights:") then
		if lb.mode == 1 and brightness <= node.param2 then
			return
		end
		if lb.mode == 2 and brightness >= node.param2 then
			return
		end
		if lb.mode == 4 then
			if brightness <= node.param2 then
				return
			end
			brightness = mf((brightness + node.param2) / 2 + 0.5)
			if brightness < 1 then
				return
			end
			new_node_name = "cozylights:light" .. brightness
		elseif lb.mode == 5 then
			if brightness >= node.param2 then
				return
			end
			brightness = mf((brightness + node.param2) / 2)
			new_node_name = "cozylights:light" .. brightness
			if brightness < 1 then
				brightness = 0
				new_node_name = "air"
			end
		elseif lb.mode == 6 then
			brightness = mf((brightness + node.param2) / 2 + 0.5)
			new_node_name = "cozylights:light" .. brightness
			if brightness < 0 then
				brightness = 0
				new_node_name = "air"
			end
		end
		minetest.set_node(pos, {
			name = new_node_name,
			param2 = brightness,
		})
	end
end

--this function pulls numbers out of its ass instead of seriously computing everything, so its faster
--some nodes are being missed for big spheres
function cozylights:draw_brush_light(pos, lb)
	local t = os.clock()
	local radius = lb.radius
	if radius == 0 then
		if not lb.is_replay and lb.player_name then
			local hist = cozylights.cozyplayers[lb.player_name].lbrush_history
			if hist then
				table.insert(hist, {
					pos = vector.new(pos),
					radius = 0,
					brightness = lb.brightness,
					strength = lb.strength,
					mode = lb.mode,
				})
				if #hist > 200 then
					table.remove(hist, 1)
				end
			end
		end
		draw_one_node(pos, lb)
		return
	end
	local mode = lb.mode
	local brightness = lb.brightness
	local dim_levels = calc_dims_for_brush(brightness, radius, lb.strength, mode == 2 and true or false)
	local vm = cozylights.get_voxel_manip()
	local emin, emax = vm:read_from_map(vector.subtract(pos, radius + 1), vector.add(pos, radius + 1))
	local data = vm:get_data()
	local param2data = vm:get_param2_data()
	local a = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local sphere_surface = cozylights:get_sphere_surface(radius)
	local ylvl = 1
	if lb.is_replay then
		ylvl = 0
	else
		local cid = data[a:index(pos.x, pos.y - 1, pos.z)]
		local cida = data[a:index(pos.x, pos.y + 1, pos.z)]
		local c_light_debug14 = c_lights[14] + 14
		if cid and cida then
			if
				(cid == c_air or (cid >= c_lights[1] and cid <= c_light_debug14))
				and cida ~= c_air
				and (cida < c_lights[1] or cida > c_light_debug14)
			then
				ylvl = -1
			end
		else
			return
		end
	end
	pos.y = pos.y + ylvl
	if not lb.is_replay and lb.player_name then
		local hist = cozylights.cozyplayers[lb.player_name].lbrush_history
		if hist then
			table.insert(hist, {
				pos = vector.new(pos),
				radius = radius,
				brightness = brightness,
				strength = lb.strength,
				mode = mode,
			})
			if #hist > 200 then
				table.remove(hist, 1)
			end
		end
	end
	if mode == 1 then
		if cozylights.always_fix_edges == true then
			local visited_pos = {}
			for i, pos2 in ipairs(sphere_surface) do
				local end_pos = { x = pos.x + pos2.x, y = pos.y + pos2.y, z = pos.z + pos2.z }
				cozylights:lightcast_fix_edges(
					pos,
					vector.direction(pos, end_pos),
					radius,
					data,
					param2data,
					a,
					dim_levels,
					visited_pos
				)
			end
		else
			for i, pos2 in ipairs(sphere_surface) do
				local end_pos = { x = pos.x + pos2.x, y = pos.y + pos2.y, z = pos.z + pos2.z }
				cozylights:lightcast(pos, vector.direction(pos, end_pos), radius, data, param2data, a, dim_levels)
			end
		end
	elseif mode == 2 then
		if cozylights.always_fix_edges == true then
			local visited_pos = {}
			for i, pos2 in ipairs(sphere_surface) do
				local end_pos = { x = pos.x + pos2.x, y = pos.y + pos2.y, z = pos.z + pos2.z }
				cozylights:lightcast_erase_fix_edges(
					pos,
					vector.direction(pos, end_pos),
					radius,
					data,
					param2data,
					a,
					dim_levels,
					visited_pos
				)
			end
		else
			for i, pos2 in ipairs(sphere_surface) do
				local end_pos = { x = pos.x + pos2.x, y = pos.y + pos2.y, z = pos.z + pos2.z }
				cozylights:lightcast_erase(pos, vector.direction(pos, end_pos), radius, data, param2data, a, dim_levels)
			end
		end
	elseif mode == 3 then
		if cozylights.always_fix_edges == true then
			local visited_pos = {}
			for i, pos2 in ipairs(sphere_surface) do
				local end_pos = { x = pos.x + pos2.x, y = pos.y + pos2.y, z = pos.z + pos2.z }
				cozylights:lightcast_override_fix_edges(
					pos,
					vector.direction(pos, end_pos),
					radius,
					data,
					param2data,
					a,
					dim_levels,
					visited_pos
				)
			end
		else
			for i, pos2 in ipairs(sphere_surface) do
				local end_pos = { x = pos.x + pos2.x, y = pos.y + pos2.y, z = pos.z + pos2.z }
				cozylights:lightcast_override(
					pos,
					vector.direction(pos, end_pos),
					radius,
					data,
					param2data,
					a,
					dim_levels
				)
			end
		end
	elseif mode == 4 then
		if cozylights.always_fix_edges == true then
			local visited_pos = {}
			for i, pos2 in ipairs(sphere_surface) do
				local end_pos = { x = pos.x + pos2.x, y = pos.y + pos2.y, z = pos.z + pos2.z }
				cozylights:lightcast_lighten_fix_edges(
					pos,
					vector.direction(pos, end_pos),
					radius,
					data,
					param2data,
					a,
					dim_levels,
					visited_pos
				)
			end
		else
			for i, pos2 in ipairs(sphere_surface) do
				local end_pos = { x = pos.x + pos2.x, y = pos.y + pos2.y, z = pos.z + pos2.z }
				cozylights:lightcast_lighten(
					pos,
					vector.direction(pos, end_pos),
					radius,
					data,
					param2data,
					a,
					dim_levels
				)
			end
		end
	elseif mode == 5 then
		if cozylights.always_fix_edges == true then
			local visited_pos = {}
			for i, pos2 in ipairs(sphere_surface) do
				local end_pos = { x = pos.x + pos2.x, y = pos.y + pos2.y, z = pos.z + pos2.z }
				cozylights:lightcast_darken_fix_edges(
					pos,
					vector.direction(pos, end_pos),
					radius,
					data,
					param2data,
					a,
					dim_levels,
					visited_pos
				)
			end
		else
			for i, pos2 in ipairs(sphere_surface) do
				local end_pos = { x = pos.x + pos2.x, y = pos.y + pos2.y, z = pos.z + pos2.z }
				cozylights:lightcast_darken(
					pos,
					vector.direction(pos, end_pos),
					radius,
					data,
					param2data,
					a,
					dim_levels
				)
			end
		end
	else
		if cozylights.always_fix_edges == true then
			local visited_pos = {}
			for i, pos2 in ipairs(sphere_surface) do
				local end_pos = { x = pos.x + pos2.x, y = pos.y + pos2.y, z = pos.z + pos2.z }
				cozylights:lightcast_blend_fix_edges(
					pos,
					vector.direction(pos, end_pos),
					radius,
					data,
					param2data,
					a,
					dim_levels,
					visited_pos
				)
			end
		else
			for i, pos2 in ipairs(sphere_surface) do
				local end_pos = { x = pos.x + pos2.x, y = pos.y + pos2.y, z = pos.z + pos2.z }
				cozylights:lightcast_blend(pos, vector.direction(pos, end_pos), radius, data, param2data, a, dim_levels)
			end
		end
	end
	vm:set_data(data)
	vm:set_param2_data(param2data)
	vm:update_liquids()
	vm:write_to_map()
	gent_total = gent_total + mf((os.clock() - t) * 1000)
	gent_count = gent_count + 1
	print("Av draw time " .. mf(gent_total / gent_count) .. " ms. Sample of: " .. gent_count)
end

function cozylights:undo_last_brush(player_name)
	local cp = cozylights.cozyplayers[player_name]
	if not cp or not cp.lbrush_history or #cp.lbrush_history == 0 then
		return false
	end
	local stroke = table.remove(cp.lbrush_history)
	local wipe_rad = stroke.radius + 2
	local minp = vector.subtract(stroke.pos, wipe_rad)
	local maxp = vector.add(stroke.pos, wipe_rad)
	local vm = cozylights.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local data = vm:get_data()
	local param2data = vm:get_param2_data()
	local a = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local c_air = minetest.get_content_id("air")
	local c_light1 = minetest.get_content_id("cozylights:light1")
	local c_light_debug14 = c_light1 + 27
	for i in a:iterp(minp, maxp) do
		local cid = data[i]
		if cid >= c_light1 and cid <= c_light_debug14 then
			data[i] = c_air
			param2data[i] = 0
		end
	end
	vm:set_data(data)
	vm:set_param2_data(param2data)
	vm:write_to_map()
	for i = 1, #cp.lbrush_history do
		local h_stroke = cp.lbrush_history[i]
		if vector.distance(h_stroke.pos, stroke.pos) <= (h_stroke.radius + wipe_rad) then
			local lb_replay = {
				radius = h_stroke.radius,
				brightness = h_stroke.brightness,
				strength = h_stroke.strength,
				mode = h_stroke.mode,
				is_replay = true,
			}
			cozylights:draw_brush_light(vector.new(h_stroke.pos), lb_replay)
		end
	end
	local posrebuilds = {}
	local tx_locks = {} --prevents duplicates
	for bound, nodenames in pairs(cozylights.rebuild_bounds) do
		local search_range = bound + wipe_rad
		local s_minp = vector.subtract(stroke.pos, search_range)
		local s_maxp = vector.add(stroke.pos, search_range)
		local found = cozylights.find_nodes_in_area(s_minp, s_maxp, nodenames)
		for i = 1, #found do
			local f_pos = found[i]
			local f_hash = cozylights.hash_pos(f_pos)
			if not tx_locks[f_hash] then
				tx_locks[f_hash] = true
				posrebuilds[#posrebuilds + 1] = f_pos
			end
		end
	end
	local single_light_queue = cozylights.single_light_queue
	local sources_batched = {}
	for i = 1, #posrebuilds do
		local source_pos = posrebuilds[i]
		local f_hash = cozylights.hash_pos(source_pos)
		local node = cozylights.get_node(source_pos)
		local cozy_item = cozylights.cozy_items[node.name]
		if cozy_item then
			local rebuild_radius, _ = cozylights:calc_dims(node.name, cozy_item)
			local dist = vector.distance(stroke.pos, source_pos)
			if dist <= (rebuild_radius + wipe_rad) then
				cozylights.drawn_nodes[f_hash] = nil
				cozylights.recently_updated[f_hash] = nil
				if stroke.radius > 10 then
					sources_batched[#sources_batched + 1] = { pos = source_pos, cozy_item = cozy_item }
				else
					single_light_queue[#single_light_queue + 1] = { pos = source_pos, cozy_item = cozy_item }
				end
			end
		end
	end
	if #sources_batched > 0 then
		cozylights:push_area_queue(minp, maxp, sources_batched)
	end
	return true
end

function cozylights:get_brush_settings(itemstack, player_name)
	local meta = itemstack:get_meta()
	return {
		radius = meta:contains("radius") and meta:get_int("radius") or 3,
		brightness = meta:contains("brightness") and meta:get_int("brightness") or 5,
		strength = meta:contains("strength") and meta:get_float("strength") or 0.3,
		mode = meta:contains("mode") and meta:get_int("mode") or 1,
		player_name = player_name,
	}
end

function cozylights:update_wield_hud(player, cozyplayer, itemstack, duration)
	local lb = cozylights:get_brush_settings(itemstack, cozyplayer.name)
	local mode_names = { "Default", "Erase", "Override", "Lighten", "Darken", "Blend" }
	local hud_text = string.format(
		"Radius: %d\nBrightness: %d\nStrength: %.2f\nMode: %s",
		lb.radius,
		lb.brightness,
		lb.strength,
		mode_names[lb.mode] or "Default"
	)
	if cozyplayer.hud_id then
		player:hud_change(cozyplayer.hud_id, "text", hud_text)
	else
		cozyplayer.hud_id = player:hud_add({
			hud_elem_type = "text",
			position = { x = 0.22, y = 0.5 },
			name = "cozylights_brush_hud",
			scale = { x = 90, y = 90 },
			text = hud_text,
			number = 0xFFFFFF, -- White hex
			alignment = { x = 1, y = 0 },
			offset = { x = 0, y = 0 },
		})
	end
	cozyplayer.hud_timeout = duration or 2.0
end

function cozylights:remove_wield_hud(player, cozyplayer)
	if cozyplayer.hud_id then
		player:hud_remove(cozyplayer.hud_id)
		cozyplayer.hud_id = nil
	end
end
