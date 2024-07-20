local c_air = minetest.get_content_id("air")
local c_light1 = minetest.get_content_id("cozylights:light1")

local c_lights = { c_light1, c_light1 + 1, c_light1 + 2, c_light1 + 3, c_light1 + 4, c_light1 + 5, c_light1 + 6,
	c_light1 + 7, c_light1 + 8, c_light1 + 9, c_light1 + 10, c_light1 + 11, c_light1 + 12, c_light1 + 13 }
local c_light14 = c_lights[14]
local c_light_debug14 = minetest.get_content_id("cozylights:light_debug14")

local mf = math.floor

local clearlights = {
	params = "<size>",
	description = "removes cozy and debug light nodes",
	func = function(name, param)
		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		local size = tonumber(param) or cozylights.default_size
		minetest.log("action", name .. " uses /clearlights "..size.." at position: "..dump(pos))
		if size >= 121 then
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
	description = "force rebuilds lights in the area",
	func = function(name, param)
		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		local size = tonumber(param) or cozylights.default_size
		minetest.log("action", name .. " uses /rebuildlights "..size.." at position: "..dump(pos))
		if size >= 121 then
			return false, "Radius is too big"
		end
		local posrebuilds = minetest.find_nodes_in_area(vector.subtract(pos, size+1), vector.add(pos, size+1), cozylights.cozy_nodes)
		print(#posrebuilds)

		local _,_,vm,data,param2data,a = cozylights:getVoxelManipData(pos, size+25)
		for i=1,#posrebuilds, 1 do
			local p = posrebuilds[i]
			local node = minetest.get_node(p)
			print(dump(node))
			cozylights:draw_node_light(p, cozylights.cozy_items[node.name],vm,a,data,param2data)
		end
		cozylights:setVoxelManipData(vm,data,param2data,true)
		return true, "Done."
	end,
}

local fixedges = {
	params = "<size>",
	description = "fixes edges for all lights in the area",
	func = function(name, param)
		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		local size = tonumber(param) or cozylights.default_size
		minetest.log("action", name .. " uses /fixedges "..size.." at position: "..dump(pos))
		if size >= 121 then
			return false, "Radius is too big"
		end
		local posrebuilds = minetest.find_nodes_in_area(vector.subtract(pos, size+1), vector.add(pos, size+1), cozylights.cozy_nodes)
		for i=1,#posrebuilds do
			local node = minetest.get_node(posrebuilds[i])
			cozylights:draw_node_light(posrebuilds[i], cozylights.cozy_items[node.name])
		end
		return true, "Done."
	end,
}

local cozydebugon = {
	params = "<size>",
	description = "replaces cozy light nodes with debug light nodes which are visible and interactable in an area",
	func = function(name, param)
		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		local size = tonumber(param) or cozylights.default_size
		minetest.log("action", name .. " uses /cozydebugon "..size.." at position: "..dump(pos))
		if size >= 121 then
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
		minetest.log("action", name .. " uses /cozydebugoff "..size.." at position: "..dump(pos))
		if size >= 121 then
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
		minetest.log("action", name .. " uses /optimizeformobile "..size.." at position: "..dump(pos))
		if size >= 121 then
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
		minetest.log("action", name .. " uses /optimizeformobile "..brightness.." "..radius.." "..strength.." at position: "..dump(pos))
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

local cozysettings = {
	params = "<brightness> <reach_factor> <dim_factor>",
	privs = {},
	description = "changes global ambient light settings",
	func = function(name, param)
		local brightness_, reach_factor_, dim_factor_ = string.match(param, "^([%d.~-]+)[, ] *([%d.~-]+)[, ] *([%d.~-]+)$")
		brightness_ = tonumber(brightness_)
		if brightness_ ~= nil then
			cozylights.brightness = brightness_
			minetest.settings:set("cozylights_brightness",brightness_)
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
		minetest.log("action", name .. " uses /daynightratio "..ratio.." at position: "..dump(pos))
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
		minetest.log("action", name .. " uses /clearlights "..size.." at position: "..dump(pos))
		if size >= 121 then
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
		minetest.log("action", name .. " uses /fixtorches "..size.." at position: "..dump(pos))
		if size >= 121 then
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

minetest.register_chatcommand("cozysettings", cozysettings)
minetest.register_chatcommand("zs", cozysettings)

minetest.register_chatcommand("daynightratio", daynightratio)
minetest.register_chatcommand("zdnr", daynightratio)

minetest.register_chatcommand("cozyadjust", cozyadjust)
minetest.register_chatcommand("za", cozyadjust)

minetest.register_chatcommand("fixtorches", fixtorches)
minetest.register_chatcommand("zft", fixtorches)