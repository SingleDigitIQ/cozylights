local mf = math.floor

local function on_secondary_use(user)
	local lb = cozylights.cozyplayers[user:get_player_name()].lbrush
	local settings_formspec = {
  		"formspec_version[4]",
  		--"size[6,6.4]",
		"size[5.2,5]",
		"label[1.45,0.5;Light Brush Settings]",

		"label[0.95,1.35;Radius]",
  		"field[3.6,1.1;0.7,0.5;radius;;"..lb.radius.."]",
		"tooltip[0.95,1.1;3.4,0.5;If radius is 0 then only one node will be affected by the brush.\n"..
			"If not zero then it's a sphere of affected nodes with specified radius.\n"..
			"As of now max radius is only 120.\n"..
			"With radiuses over 30 mouse hold as of now does not work, only point and click]",

		"label[0.95,2.05;Brightness]",
  		"field[3.6,1.8;0.7,0.5;brightness;;"..lb.brightness.."]",
  		"tooltip[0.95,1.8;3.4,0.5;Brightness - for most brush modes values are from 1 to 14, corresponding to engine light levels.\n"..
			"If brush mode is 'darken' or 'override' then 0 will replace lowest light levels with air.]",

		"label[0.95,2.75;Strength]",
		"field[3.6,2.5;0.7,0.5;strength;;"..lb.strength.."]",
		"tooltip[0.95,2.5;3.4,0.5;Strength, can be from 0 to 1, decimal values of any precision are valid.\n"..
			"Determines how bright(relative to brightness setting) light nodes in affected area will be.]",
		
		"label[0.95,3.45;Brush Mode]",
		"dropdown[2.8,3.2;1.5,0.5;mode;default,erase,override,lighten,darken,blend;"..lb.mode.."]",
		"tooltip[0.95,3.2;3.4,0.5;\nDefault - replace only dimmer light nodes or air with brush.\n\n"..
			"Erase - inverse of default, replaces only lighter nodes with darker nodes or air if brightness is 0.\n\n"..	
			"Override - set light nodes as brush settings dictate regardless of difference in brigthness.\n\n"..
			"Lighten - milder than default mode.\n\n"..
			"Darken - milder erase, does not darken below light 1(does not replace with air).\n\n"..
			"Blend - blend affected nodes' brigthness with brush brigthness.\n"..
			"Even though behaves correctly, as of now looks weird and unintuitive if radius is not 0.]",
		--"checkbox[1.7,4.6;cover_only_surfaces;cover only surfaces;"..(lb.cover_only_surfaces == 1 and "true" or "false").."]",
		--"tooltip[1.7,4.4;2.6,0.4;if enabled brush will not fill up the air with light above the ground;"..bgcolor..";#FFFFFF]",
		--"button_exit[1,5.1;4,0.8;confirm;Confirm]",
		"button_exit[1.1,4;3,0.8;confirm;Confirm]",
	}
	minetest.show_formspec(user:get_player_name(), "cozylights:brush_settings",table.concat(settings_formspec, ""))
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
			local nodenameunder = minetest.get_node(pointed_thing.under).name
			local nodedefunder = minetest.registered_nodes[nodenameunder]
			local lb = cozylights.cozyplayers[user:get_player_name()].lbrush
			local above = pointed_thing.above
			if nodenameunder ~= "air" and nodedefunder.buildable_to == true then
				above.y = above.y - 1
			end
			local above_hash = above.x + (above.y)*100 + above.z*10000
			lb.pos_hash = above_hash
			cozylights:draw_brush_light(pointed_thing.above, lb)
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
	if formname ~= ("cozylights:brush_settings") then return end
	if player == nil then return end
	local lb = cozylights.cozyplayers[player:get_player_name()].lbrush
	if fields.brightness then
		local brightness = tonumber(fields.brightness) > 14 and 14 or tonumber(fields.brightness)
		lb.brightness = brightness < 0 and 0 or mf(brightness or 0)
	end
	if fields.radius then
		local radius = tonumber(fields.radius) > 200 and 200 or tonumber(fields.radius)
		lb.radius = radius < 0 and 0 or mf(radius or 0)
	end
	if fields.strength then
		local strength = tonumber(fields.strength) > 1 and 1 or tonumber(fields.strength)
		lb.strength = strength < 0 and 0 or strength
	end
	if fields.mode then
		local mode = fields.mode
		local idx = 6
		if mode == "default" then
			idx = 1
		elseif mode == "erase" then
			idx = 2
		elseif mode == "override" then
			idx = 3
		elseif mode == "lighten" then
			idx = 4
		elseif mode == "darken" then
			idx = 5
		end
		lb.mode = idx
	end
	if fields.cover_only_surfaces then
	  	lb.cover_only_surfaces = fields.cover_only_surfaces == "true" and 1 or 0
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
	strength = strength*5
	dim_levels[1] = brightness
	if even ~= true then
		
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
	else
		for i = 2, radius do
			dim_levels[i] = brightness
		end
	end

	return dim_levels
end

local c_air = minetest.get_content_id("air")
local c_light1 = minetest.get_content_id("cozylights:light1")
local c_lights = { c_light1, c_light1 + 1, c_light1 + 2, c_light1 + 3, c_light1 + 4, c_light1 + 5, c_light1 + 6,
	c_light1 + 7, c_light1 + 8, c_light1 + 9, c_light1 + 10, c_light1 + 11, c_light1 + 12, c_light1 + 13 }
local gent_total = 0
local gent_count = 0

local function draw_one_node(pos,lb)
	local node = minetest.get_node(pos)
	local brightness = lb.brightness
	local new_node_name = "cozylights:light"..brightness
	if brightness == 0 then
		new_node_name = "air"
	end

	if node.name == "air" and new_node_name ~= node.name then
		minetest.set_node(
			pos,
			{
				name=new_node_name,
				param2=brightness
			}
		)
		return
	end
	if string.find(node.name,"cozylights:") then
		if lb.mode == 1 and brightness <= node.param2 then return end
		if lb.mode == 2 and brightness >= node.param2 then return end
		if lb.mode == 4 then
			if brightness <= node.param2 then return end
			brightness = mf((brightness+node.param2)/2+0.5)
			if brightness < 1 then return end
			new_node_name = "cozylights:light"..brightness
		elseif lb.mode == 5 then
			if brightness >= node.param2 then return end
			brightness = mf((brightness+node.param2)/2)
			new_node_name = "cozylights:light"..brightness
			if brightness < 1 then
				brightness = 0
				new_node_name = "air"
			end
		elseif lb.mode == 6 then
			brightness = mf((brightness+node.param2)/2+0.5)
			new_node_name = "cozylights:light"..brightness
			if brightness < 0 then
				brightness = 0
				new_node_name = "air"
			end
		end
		minetest.set_node(
			pos,
			{
				name=new_node_name,
				param2=brightness
			}
		)
	end
end


--this function pulls numbers out of its ass instead of seriously computing everything, so its faster
--some nodes are being missed for big spheres
function cozylights:draw_brush_light(pos, lb)
	local t = os.clock()
	local radius = lb.radius
	if radius == 0 then
		draw_one_node(pos,lb)
		return
	end
	local mode = lb.mode
	local brightness = lb.brightness
	local dim_levels = calc_dims_for_brush(brightness,radius,lb.strength, mode==2 and true or false)
	print("dim_levels:"..cozylights:dump(dim_levels))
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
		if (cid == c_air or (cid >= c_lights[1] and cid <= c_lights[14]))
			and cida ~= c_air and (cida < c_lights[1] or cida > c_lights[14])
		then
			ylvl = -1
		end
	else
		return
	end
	pos.y = pos.y + ylvl

	if mode == 1 then
		if cozylights.always_fix_edges == true then
			local visited_pos = {}
			for i,pos2 in ipairs(sphere_surface) do
				local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
				cozylights:lightcast_fix_edges(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels,visited_pos)
			end
		else
			for i,pos2 in ipairs(sphere_surface) do
				local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
				cozylights:lightcast(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels)
			end
		end
	elseif mode == 2 then
		if cozylights.always_fix_edges == true then
			local visited_pos = {}
			for i,pos2 in ipairs(sphere_surface) do
				local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
				cozylights:lightcast_erase_fix_edges(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels,visited_pos)
			end
		else
			for i,pos2 in ipairs(sphere_surface) do
				local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
				cozylights:lightcast_erase(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels)
			end
		end
	elseif mode == 3 then
		if cozylights.always_fix_edges == true then
			local visited_pos = {}
			for i,pos2 in ipairs(sphere_surface) do
				local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
				cozylights:lightcast_override_fix_edges(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels,visited_pos)
			end
		else
			for i,pos2 in ipairs(sphere_surface) do
				local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
				cozylights:lightcast_override(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels)
			end
		end
	elseif mode == 4 then
		if cozylights.always_fix_edges == true then
			local visited_pos = {}
			for i,pos2 in ipairs(sphere_surface) do
				local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
				cozylights:lightcast_lighten_fix_edges(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels,visited_pos)
			end
		else
			for i,pos2 in ipairs(sphere_surface) do
				local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
				cozylights:lightcast_lighten(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels)
			end
		end
	elseif mode == 5 then
		if cozylights.always_fix_edges == true then
			local visited_pos = {}
			for i,pos2 in ipairs(sphere_surface) do
				local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
				cozylights:lightcast_darken_fix_edges(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels,visited_pos)
			end
		else
			for i,pos2 in ipairs(sphere_surface) do
				local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
				cozylights:lightcast_darken(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels)
			end
		end
	else
		if cozylights.always_fix_edges == true then
			local visited_pos = {}
			for i,pos2 in ipairs(sphere_surface) do
				local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
				cozylights:lightcast_blend_fix_edges(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels,visited_pos)
			end
		else
			for i,pos2 in ipairs(sphere_surface) do
				local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
				cozylights:lightcast_blend(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels)
			end
		end
	end
	vm:set_data(data)
	vm:set_param2_data(param2data)
	vm:update_liquids()
	vm:write_to_map()
	gent_total = gent_total + mf((os.clock() - t) * 1000)
	gent_count = gent_count + 1
	print("Av draw time " .. mf(gent_total/gent_count) .. " ms. Sample of: "..gent_count)
end
