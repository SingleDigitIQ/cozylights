local mf = math.floor

local function on_secondary_use(user)
	local lbrush = cozylights.cozyplayers[user:get_player_name()].lbrush
	local settings_formspec = {
  		"formspec_version[4]",
  		"size[8,5.6]",
  		"field[0.5,0.7;4,0.8;radius;radius;"..lbrush.radius.."]",
  		"field[0.5,1.9;4,0.8;brightness;brightness;"..lbrush.brightness.."]",
  		"field[0.5,3.1;4,0.8;strength;strength;"..lbrush.strength.."]",
  		"checkbox[0.5,4.3;cover_only_surfaces;cover_only_surfaces;"..(lbrush.cover_only_surfaces == 1 and "true" or "false").."]",
  		"button_exit[0.5,4.6;7,0.8;confirm;Confirm]",
	}
	minetest.show_formspec(user:get_player_name(), "cozylights:settings",table.concat(settings_formspec, ""))
end

minetest.register_tool("cozylights:light_brush", {
	description = "Light Brush",
	inventory_image = "light_brush.png",
	wield_image = "light_brush1.png^[transformR90",
	tool_capabilities = {
		full_punch_interval = 0.3,
		max_drop_level = 1,
	},
	range = 40.0,
	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.under then
			local nodenameunder = minetest.get_node(pointed_thing.under).name
			local nodedefunder = minetest.registered_nodes[nodenameunder]
			local lb = cozylights.cozyplayers[user:get_player_name()].lbrush
			local above = pointed_thing.above
			if nodenameunder ~= "air" and nodedefunder.buildable_to == true then
				above.y = above.y - 1
				local above_hash = above.x + (above.y)*100 + above.z*10000
				lb.pos_hash = above_hash
				cozylights:draw_brush_light(pointed_thing.above, lb.brightness, lb.radius, lb.strength)
			else
				local above_hash = above.x + (above.y)*100 + above.z*10000
				lb.pos_hash = above_hash
				cozylights:draw_brush_light(pointed_thing.above, lb.brightness, lb.radius, lb.strength)
			end
		end
	end,
	on_place = function(_, placer)
		on_secondary_use(placer)
	end,
	on_secondary_use = function(_, user)
		on_secondary_use(user)
	end,
	sound = {breaks = "default_tool_breaks"}
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= ("cozylights:settings") then return end
	if player == nil then return end
	local lbrush = cozylights.cozyplayers[player:get_player_name()].lbrush
	if fields.reach_factor then
		lbrush.reach_factor = tonumber(fields.reach_factor)
	end
	if fields.dim_factor then
		lbrush.dim_factor = tonumber(fields.dim_factor)
	end
	if fields.brightness then
		local brightness = tonumber(fields.brightness) > 14 and 14 or tonumber(fields.brightness)
		lbrush.brightness = brightness < 0 and 0 or brightness
	end

	if fields.radius then
		local radius = tonumber(fields.radius) > 200 and 200 or tonumber(fields.radius)
		lbrush.radius = radius < 1 and 1 or radius
	end
	if fields.strength then
		local strength = tonumber(fields.strength) > 1 and 1 or tonumber(fields.strength)
		lbrush.strength = strength < 0 and 0 or strength
	end
	if fields.cover_only_surfaces then
	  	lbrush.cover_only_surfaces = fields.cover_only_surfaces == "true" and 1 or 0
	end
  end)

local function calc_dims_for_brush(brightness, radius, strength)
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
	strength = strength*5
	dim_levels[1] = brightness
	for i = 2, radius do
		local dim = math.sqrt(math.sqrt(i)) * (6-strength)
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
	return dim_levels
end

local c_air = 126
local c_light1 = minetest.get_content_id("cozylights:light1")
local c_lights = { c_light1, c_light1 + 1, c_light1 + 2, c_light1 + 3, c_light1 + 4, c_light1 + 5, c_light1 + 6,
	c_light1 + 7, c_light1 + 8, c_light1 + 9, c_light1 + 10, c_light1 + 11, c_light1 + 12, c_light1 + 13 }
local gent_total = 0
local gent_count = 0

--this function pulls numbers out of its ass instead of seriously computing everything, so its faster
--some nodes are being missed for big spheres
function cozylights:draw_brush_light(pos, brightness, radius, strength)
	local t = os.clock()
	local dim_levels = calc_dims_for_brush(brightness, radius, strength)
	--minetest.chat_send_all("dim_levels:"..dump(dim_levels))
	local vm  = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(vector.subtract(pos, radius+1), vector.add(pos, radius+1))
	local data = vm:get_data()
	local param2data = vm:get_param2_data()
	local a = VoxelArea:new{
		MinEdge = emin,
		MaxEdge = emax
	}
	local sphere_surface = cozylights:get_sphere_surface(radius)
	local ylvl = 1
	local cid = data[a:index(pos.x,pos.y-1,pos.z)]
	local cida = data[a:index(pos.x,pos.y+1,pos.z)]
	if cid and cida then
		if (cid == 126 or (cid >= c_lights[1] and cid <= c_lights[14]))
			and cida ~= 126 and (cida < c_lights[1] or cida > c_lights[14])
		then
			ylvl = -1
		end
	else
		return
	end
	pos.y = pos.y + ylvl
	--data[a:indexp(pos)] = c_lights[brightness]
	if cozylights.always_fix_edges == true then
		minetest.chat_send_all("running with fix edges enabled")
		local visited_pos = {}
		for i,pos2 in ipairs(sphere_surface) do
			local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
			cozylights:lightcast(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels,visited_pos)
		end
	else
		for i,pos2 in ipairs(sphere_surface) do
			local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
			cozylights:lightcast_no_fix_edges(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels)
		end
	end
	vm:set_data(data)
	vm:set_param2_data(param2data)
	vm:write_to_map()
	gent_total = gent_total + mf((os.clock() - t) * 1000)
	gent_count = gent_count + 1
	minetest.chat_send_all("Average draw time " .. mf(gent_total/gent_count) .. " ms. Sample of: "..gent_count)
end
