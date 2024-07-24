local c_air = minetest.get_content_id("air")
local c_light1 = minetest.get_content_id("cozylights:light1")

local c_lights = { c_light1, c_light1 + 1, c_light1 + 2, c_light1 + 3, c_light1 + 4, c_light1 + 5, c_light1 + 6,
	c_light1 + 7, c_light1 + 8, c_light1 + 9, c_light1 + 10, c_light1 + 11, c_light1 + 12, c_light1 + 13 }
local c_light14 = c_lights[14]
local c_light_debug1 = minetest.get_content_id("cozylights:light_debug1")
local c_light_debug14 = c_light_debug1 + 13

local mf = math.floor

local clearlights = {
	params = "<size>",
	description = "removes cozy and debug light nodes. max radius is 120 for now",
	func = function(name, param)
		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		local size = tonumber(param) or cozylights.default_size
		minetest.log("action", name .. " uses /clearlights "..size.." at position: "..cozylights:dump(pos))
		if size > 120 then
			return false, "Radius is too big"
		end
		local minp,maxp,vm,data,param2data,a = cozylights:getVoxelManipData(pos,size)
		for i in a:iterp(minp, maxp) do
			local cid = data[i]
			if cid >= c_light1 and cid <= c_light_debug14 then
				data[i] = c_air
				param2data[i] = 0
			end
		end
		cozylights:setVoxelManipData(vm,data,param2data,true)
		return true, "Done."
	end,
}

local rebuildlights = {
	params = "<size>",
	description = "force rebuilds lights in the area. max radius is 120 for now",
	func = function(name, param)
		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		local size = tonumber(param) or cozylights.default_size
		minetest.log("action", name .. " uses /rebuildlights "..size.." at position: "..cozylights:dump(pos))
		if size > 120 then return false, "Radius is too big" end
		local minp,maxp,vm,data,param2data,a = cozylights:getVoxelManipData(pos, size)
		for i in a:iterp(minp,maxp) do
			local node_name = minetest.get_name_from_content_id(data[i])
			local cozy_item = cozylights.cozy_items[node_name]
			if cozy_item ~= nil then
				local radius, _ = cozylights:calc_dims(cozy_item)
				local posrebuild = a:position(i)
			 	if vector.in_area(vector.subtract(posrebuild, radius), minp, maxp)
			 		and vector.in_area(vector.add(posrebuild, radius), minp, maxp)
				then
					cozylights:draw_node_light(posrebuild, cozy_item, vm, a, data, param2data)
				else
					local single_light_queue = cozylights.single_light_queue
					single_light_queue[#single_light_queue+1] = {
						pos=posrebuild,
						cozy_item=cozy_item
					}
				end
			end
		end
		cozylights:setVoxelManipData(vm,data,param2data,true)
		return true, "Done."
	end,
}

local fixedges = {
	params = "<size>",
	description = "same as rebuild lights but additionally fixes edges for all lights in the area, regardless of always_fix_edges setting. max radius is 120",
	func = function(name, param)
		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		local size = tonumber(param) or cozylights.default_size
		minetest.log("action", name .. " uses /fixedges "..size.." at position: "..cozylights:dump(pos))
		if size > 120 then return false, "Radius is too big" end
		local minp,maxp,vm,data,param2data,a = cozylights:getVoxelManipData(pos, size)
		for i in a:iterp(minp,maxp) do
			local node_name = minetest.get_name_from_content_id(data[i])
			local cozy_item = cozylights.cozy_items[node_name]
			if cozy_item ~= nil then
				local radius, _ = cozylights:calc_dims(cozy_item)
				local posrebuild = a:position(i)
			 	if vector.in_area(vector.subtract(posrebuild, radius), minp, maxp)
			 		and vector.in_area(vector.add(posrebuild, radius), minp, maxp)
				then
					cozylights:draw_node_light(posrebuild, cozy_item, vm, a, data, param2data, true)
				else
					local single_light_queue = cozylights.single_light_queue
					single_light_queue[#single_light_queue+1] = {
						pos=posrebuild,
						cozy_item=cozy_item
					}
				end
			end
		end
		cozylights:setVoxelManipData(vm,data,param2data,true)
		return true, "Done."
	end,
}

local cozydebugon = {
	params = "<size>",
	description = "replaces cozy light nodes with debug light nodes which are visible and interactable in an area",
	func = function(name, param)
		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		local size = tonumber(param) or cozylights.default_size
		minetest.log("action", name .. " uses /cozydebugon "..size.." at position: "..cozylights:dump(pos))
		if size > 120 then
			return false, "Radius is too big"
		end
		local minp,maxp,vm,data,_,a = cozylights:getVoxelManipData(pos,size)
		for i in a:iterp(minp, maxp) do
			local cid = data[i]
			if cid >= c_light1 and cid <= c_light14 then
				data[i] = cid + 14
			end
		end
		cozylights:setVoxelManipData(vm,data)
		return true, "Done."
	end,
}

local cozydebugoff = {
	params = "<size>",
	description = "replaces debug light nodes back with cozy light nodes in an area",
	func = function(name, param)
		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		local size = tonumber(param) or cozylights.default_size
		minetest.log("action", name .. " uses /cozydebugoff "..size.." at position: "..cozylights:dump(pos))
		if size > 120 then
			return false, "Radius is too big"
		end
		local minp,maxp,vm,data,_,a = cozylights:getVoxelManipData(pos,size)
		for i in a:iterp(minp, maxp) do
			local cid = data[i]
			if cid >= c_light14 + 1 and cid <= c_light_debug14 then
				data[i] = cid - 14
			end
		end
		cozylights:setVoxelManipData(vm,data)
		return true, "Done."
	end,
}

local optimizeformobile = {
	params = "<size>",
	description = "optimizes schematic for mobile and potato gpu",
	func = function(name, param)
		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		local size = tonumber(param) or cozylights.default_size
		minetest.log("action", name .. " uses /optimizeformobile "..size.." at position: "..cozylights:dump(pos))
		if size > 120 then
			return false, "Radius is too big"
		end
		local minp,maxp,vm,data,param2data,a = cozylights:getVoxelManipData(pos,size)
		local zstride, ystride = a.zstride, a.ystride
		local function keep(i)
			local keep = false
			for inz = -1,1 do
				for iny = -1,1 do
					for inx = -1,1 do
						local inidx = i + inx + iny*ystride + inz*zstride
						if a:containsi(inidx) then
							local incid = data[inidx]
							if incid ~= c_air and (incid < c_light1 or incid > c_light14 + 14) then
								keep = true
								break
							end
						end
					end
				end
			end
			return keep
		end
		for i in a:iterp(minp, maxp) do
			local cid = data[i]
			if cid >= c_light1 and cid <= c_light14 + 14 then
				if not keep(i) then
					data[i] = c_air
					param2data[i] = 0
				end
			end
		end
		cozylights:setVoxelManipData(vm,data,param2data,true)
		return true, "Done."
	end,
}

local spawnlight = {
	params = "<brightness> <radius> <strength>",
	description = "spawns light_brush-like light with given characteristics at player position",
	func = function(name, param)
		local brightness, radius, strength = string.match(param, "^([%d.~-]+)[, ] *([%d.~-]+)[, ] *([%d.~-]+)$")
		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		minetest.log("action", name .. " uses /optimizeformobile "..brightness.." "..radius.." "..strength.." at position: "..cozylights:dump(pos))
		brightness = mf(tonumber(brightness) or 0)
		if brightness < 0 then brightness = 0 end
		if brightness > 14 then brightness = 14 end
		radius = tonumber(radius) or 0
		if radius < 0 then radius = 0 end
		if radius > 120 then radius = 120 end
		strength = tonumber(strength) or 0
		if strength < 0 then strength = 0 end
		if strength > 1 then strength = 1 end
		local lb = {brightness=brightness,radius=radius,strength=strength,mode=0,cover_only_surfaces=0}
		cozylights:draw_brush_light(pos, lb)
		return true, "Done."
	end,
}

local cozysettingsgui = {
	privs = {},
	description = "changes global ambient light settings",
	func = function(name)
		local settings_formspec = {
			"formspec_version[4]",
			--"size[6,6.4]",
		  	"size[5.2,5.8]",
		  	"label[0.95,0.5;Global Cozy Lights Settings]",

			"label[0.95,1.35;Wielded Light Radius]",
			"field[3.6,1.1;0.7,0.5;wielded_light_radius;;"..cozylights.max_wield_light_radius.."]",
		  	"tooltip[0.95,1.1;3.4,0.5;If radius is -1 cozy wielded light is disabled, if 0 then only one node will be lit up just like in familiar Minetest wielded light mod.\n"..
				"If not zero then it's a sphere of affected nodes with specified radius.\n"..
				"Max radius is 30 as of now. If you run a potato - you may want to decrease it.]",

			"label[0.95,2.05;Global Step Time]",
			"field[3.6,1.8;0.7,0.5;step_time;;"..cozylights.step_time.."]",
			"tooltip[0.95,1.8;3.4,0.5;Cozy Lights global step - smaller value will result in more frequent, fluid update, but might be too expensive for potato.\n"..
			"Valid values are from 0.01 to 10.00]",

			"label[0.95,2.75;Brightness Factor]",
			"field[3.6,2.5;0.7,0.5;brightness_factor;;"..cozylights.brightness_factor.."]",
		  	"tooltip[0.95,2.5;3.4,0.5;Brightness factor determines how bright overall(relative to own light source brightness) the light will be.\n"..
				"Affects placed nodes(like torches, mese lamps, etc) and wielded light, but not light brush.\n"..
				"Valid values are from -10.0 to 10.0.\n"..
				"Brightness factor is not an equivalent of light source brightness(from 1 to 14), it is very low key, affects lights slightly.]",

			"label[0.95,3.45;Reach Factor]",
			"field[3.6,3.2;0.7,0.5;reach_factor;;"..cozylights.reach_factor.."]",
			"tooltip[0.95,3.2;3.4,0.5;Reach factor determines how far light of all light source nodes will reach.\n"..
				"Affects placed nodes(like torches, mese lamps, etc) and wielded light, but not light brush.\n"..
				"Valid values are from 0.0 to 10.0.\n"..
				"Not recommended to change if you are not willing to spend probably a lot of time tuning lights.\n"..
				"Not recommended to Increase if you run a potato.]",

			"label[0.95,4.15;Dim Factor]",
			"field[3.6,3.9;0.7,0.5;dim_factor;;"..cozylights.dim_factor.."]",
			"tooltip[0.95,3.9;3.4,0.5;Dim factor determines how quickly the light loses it's brightness farther from the source.\n"..
				"Affects placed nodes(like torches, mese lamps, etc) and wielded light, but not light brush.\n"..
				"Valid values are from 0.0 to 10.0.\n"..
				"Not recommended to change if you are not willing to spend probably a lot of time tuning lights.\n"..
				"Not recommended to Decrease if you run a potato.]",

		  	"button_exit[1.1,4.7;3,0.8;confirm;Confirm]", 
   		}
   		minetest.show_formspec(name, "cozylights:settings",table.concat(settings_formspec, ""))
		return true
	end,
}

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= ("cozylights:settings") then return end
	if player == nil then return end
	if fields.wielded_light_radius then
		local wielded_light_radius = tonumber(fields.wielded_light_radius) > 30 and 30 or tonumber(fields.wielded_light_radius)
		wielded_light_radius = wielded_light_radius < -1 and -1 or mf(wielded_light_radius or -1)
		cozylights:set_wielded_light_radius(wielded_light_radius)
		cozylights:switch_wielded_light(wielded_light_radius ~= -1)
	end
	if fields.step_time then
		local step_time = tonumber(fields.step_time) > 1 and 1 or tonumber(fields.step_time)
		step_time = step_time < 0.01 and 0.01 or step_time
		cozylights:set_step_time(step_time)
	end
	if fields.brightness_factor then
		local brightness_factor = tonumber(fields.brightness_factor) > 10 and 10 or tonumber(fields.brightness_factor)
		cozylights.brightness_factor = brightness_factor < -10 and -10 or brightness_factor or 3
		minetest.settings:set("cozylights_brightness_factor",cozylights.brightness_factor)
	end
	if fields.reach_factor then
		local reach_factor = tonumber(fields.reach_factor) > 10 and 10 or tonumber(fields.reach_factor)
		cozylights.reach_factor = reach_factor < 0 and 0 or reach_factor or 4
		minetest.settings:set("cozylights_reach_factor",cozylights.reach_factor)
	end
	if fields.dim_factor then
		local dim_factor = tonumber(fields.dim_factor) > 10 and 10 or tonumber(fields.dim_factor)
		cozylights.dim_factor = dim_factor < 0 and 0 or dim_factor or 9
		minetest.settings:set("cozylights_dim_factor",cozylights.dim_factor)
	end
end)


local cozysettings = {
	params = "<brightness> <reach_factor> <dim_factor>",
	privs = {},
	description = "changes global ambient light settings",
	func = function(_, param)
		local brightness_, reach_factor_, dim_factor_ = string.match(param, "^([%d.~-]+)[, ] *([%d.~-]+)[, ] *([%d.~-]+)$")
		brightness_ = tonumber(brightness_)
		if brightness_ ~= nil then
			cozylights.brightness_factor = brightness_
			minetest.settings:set("cozylights_brightness_factor",brightness_)
		end
		reach_factor_ = tonumber(reach_factor_)
		if reach_factor_ ~= nil then
			cozylights.reach_factor = reach_factor_
			minetest.settings:set("cozylights_reach_factor",reach_factor_)
		end
		dim_factor_ = tonumber(dim_factor_)
		if dim_factor_ ~= nil then
			cozylights.dim_factor = dim_factor_
			minetest.settings:set("cozylights_dim_factor",dim_factor_)
		end
		return true, "set brightness as "..brightness_..", reach_factor as "..reach_factor_..", dim_factor as "..dim_factor_
	end,
}

local daynightratio = {
	params = "<ratio>",
	description = "fixes old schematic torches alignment to walls and what not",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		local pos = vector.round(player:getpos())
		local ratio = tonumber(param)
		minetest.log("action", name .. " uses /daynightratio "..ratio.." at position: "..cozylights:dump(pos))
		if ratio > 1.0 then	ratio = 1 end
		if ratio < 0 then ratio = 0 end
		player:override_day_night_ratio(ratio)
		return true, "Done."
	end,
}

local cozyadjust = {
	params = "<size> <adjust_by> <keep_map>",
	description = "adjust brightness of all light nodes in the area.\n"..
	"keep_map is 1 by default and can be omitted, when it's 1 and adjust_by will result in a value out of bounds of 1-14(engine light levels) "..
	"even for one node in the area, the command will revert(have no effect at all), so that light map will be preserved\n"..
	"if you are ok with breaking light map, type 0 for third value",
	func = function(name, param)
		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		local size, adjust_by, keep_map = string.match(param, "^([%d.~-]+)[, ] *([%d.~-]+)[, ] *([%d.~-]+)$")
		size = mf(tonumber(size) or cozylights.default_size)
		adjust_by = mf(tonumber(adjust_by) or 1)
		keep_map = mf(tonumber(keep_map) or 1)
		minetest.log("action", name .. " uses /clearlights "..size.." at position: "..cozylights:dump(pos))
		if size > 120 then
			return false, "Radius is too big"
		end
		local minp,maxp,vm,data,param2data,a = cozylights:getVoxelManipData(pos,size)
		for i in a:iterp(minp, maxp) do
			local cid = data[i]
			if cid >= c_light1 and cid <= c_light14 then
				local precid = cid + adjust_by
				if precid >= c_light1 and precid <= c_light14 then
					data[i] = precid
					param2data[i] = precid
				elseif keep_map == 1 then
					return false, "Aborted to preserve light map."
				elseif precid > c_light14 then
					data[i] = c_light14
					param2data[i] = c_light14
				else
					data[i] = c_air
					param2data[i] = 0
				end
			elseif cid >= c_light_debug1 and cid <= c_light_debug14 then
				local precid = cid + adjust_by
				if precid >= c_light_debug1 and precid <= c_light_debug14 then
					data[i] = precid
					param2data[i] = precid
				elseif keep_map == 1 then
					return false, "Aborted to preserve light map."
				elseif precid > c_light_debug14 then
					data[i] = c_light_debug14
					param2data[i] = c_light_debug14
				else
					data[i] = c_air
					param2data[i] = 0
				end
			end

		end
		cozylights:setVoxelManipData(vm,data,param2data,true)
		return true, "Done."
	end,
}

local fixtorches = {
	params = "<size>",
	description = "fixes old schematic torches alignment to walls and what not",
	func = function(name, param)
		local placer = minetest.get_player_by_name(name)
		local pos = vector.round(placer:getpos())
		local size = mf(tonumber(param) or cozylights.default_size)
		minetest.log("action", name .. " uses /fixtorches "..size.." at position: "..cozylights:dump(pos))
		if size > 120 then
			return false, "Radius is too big"
		end
		local minp,maxp,vm,data,param2data,a = cozylights:getVoxelManipData(pos,size)
		local c_torch = minetest.get_content_id("default:torch")
		local c_torch_wall = c_torch + 1
		local c_torch_ceiling = c_torch + 2
		local ystride, zstride = a.ystride, a.zstride
		for i in a:iterp(minp, maxp) do
			if data[i] == c_torch then
				local above = minetest.registered_nodes[minetest.get_name_from_content_id(data[i-ystride])]
				if above.walkable == true then
					data[i] = c_torch_ceiling
					param2data[i] = 0
				end

				local below = minetest.registered_nodes[minetest.get_name_from_content_id(data[i-ystride])]
				if below.walkable == true then
					data[i] = c_torch
					param2data[i] = 1
				end

				if above.walkable == false and below.walkable == false then
					local plusz = minetest.registered_nodes[minetest.get_name_from_content_id(data[i + zstride])]
					data[i] = c_torch_wall
					if plusz.walkable == true then param2data[i] = 4 end
					local minusz = minetest.registered_nodes[minetest.get_name_from_content_id(data[i - zstride])]
					if minusz.walkable == true then param2data[i] = 5 end
					local plusx = minetest.registered_nodes[minetest.get_name_from_content_id(data[i + 1])]
					if plusx.walkable == true then param2data[i] = 2 end
					local minusx = minetest.registered_nodes[minetest.get_name_from_content_id(data[i - 1])]
					if minusx.walkable == true then param2data[i] = 3 end
				end
			end
		end
		cozylights:setVoxelManipData(vm,data,param2data,true)
		return true, "Done."
	end,
}

minetest.register_chatcommand("clearlights", clearlights)
minetest.register_chatcommand("zcl", clearlights)

minetest.register_chatcommand("rebuildlights", rebuildlights)
minetest.register_chatcommand("zrl", rebuildlights)

minetest.register_chatcommand("fixedges", fixedges)
minetest.register_chatcommand("zfe", fixedges)

minetest.register_chatcommand("cozydebugon", cozydebugon)
minetest.register_chatcommand("zdon", cozydebugon)

minetest.register_chatcommand("cozydebugoff", cozydebugoff)
minetest.register_chatcommand("zdoff", cozydebugoff)

minetest.register_chatcommand("optimizeformobile", optimizeformobile)
minetest.register_chatcommand("zofm", optimizeformobile)

minetest.register_chatcommand("spawnlight", spawnlight)
minetest.register_chatcommand("zsl", spawnlight)

minetest.register_chatcommand("cozysettings", cozysettingsgui)
minetest.register_chatcommand("zs", cozysettingsgui)

minetest.register_chatcommand("daynightratio", daynightratio)
minetest.register_chatcommand("zdnr", daynightratio)

minetest.register_chatcommand("cozyadjust", cozyadjust)
minetest.register_chatcommand("za", cozyadjust)

minetest.register_chatcommand("fixtorches", fixtorches)
minetest.register_chatcommand("zft", fixtorches)