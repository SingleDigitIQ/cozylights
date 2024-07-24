local c_air = minetest.get_content_id("air")
local c_light1 = minetest.get_content_id("cozylights:light1")

local c_lights = { c_light1, c_light1 + 1, c_light1 + 2, c_light1 + 3, c_light1 + 4, c_light1 + 5, c_light1 + 6,
	c_light1 + 7, c_light1 + 8, c_light1 + 9, c_light1 + 10, c_light1 + 11, c_light1 + 12, c_light1 + 13 }

local gent_total = 0
local gent_count = 0
local mf = math.floor

local function destroy_stale_wielded_light(data,param2data,a,cozyplayer)
	local c_light1 = c_lights[1]
	local c_light14 = c_lights[14]
	for j,p in ipairs(cozyplayer.prev_wielded_lights) do
		if a and a:containsp(p) then
			local idx = a:indexp(p)
			local cid = data[idx]
			if cid >= c_light1 and cid <= c_light14 then
				if param2data[idx] > 0 and param2data[idx] <= 14 then
					data[idx] = c_light1 + param2data[idx] - 1
				else
					data[idx] = c_air
				end
			end
		else
			local node = minetest.get_node(p)
			if string.find(node.name, "cozylights:light") then
				if node.param2 == 0 then
					minetest.set_node(p,{name="air"})
				else
					minetest.set_node(p,{name="cozylights:light"..node.param2})
				end
			end
		end
	end
	cozyplayer.prev_wielded_lights = {}
end

--- Like normal raycast but only covers surfaces, faster for large distances, somewhat less accurate
local function lightcast_lite(pos, dir, dirs, radius,data, param2data, a,dim_levels,cozyplayer)
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local c_light14 = c_lights[14]
	local light_nerf = 0
	for i = 1, radius do
		local x = mf(dx*i+0.5) + px
		local y = mf(dy*i+0.5) + py
		local z = mf(dz*i+0.5) + pz
		local idx = a:index(x,y,z)
		local cid = data[idx]
		if cid and (cid == c_air or (cid >= c_light1 and cid <= c_light14)) then
			for n = 1, 6 do
				local adj_idx = idx+dirs[n]
				local adj_cid = data[adj_idx]
				if adj_cid and ((adj_cid < c_light1 and adj_cid ~= c_air)or adj_cid > c_light14) then
					local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
					local light = c_lights[dim]
					if light > cid then
						data[idx] = light
						table.insert(cozyplayer.prev_wielded_lights, {x=x,y=y,z=z})
						if cid == c_air and param2data[idx] > 0 then
							param2data[idx] = 0
						end
					end
					break
				end
			end
		else
			break
		end
	end
end

function cozylights:wielded_light_cleanup(player,cozyplayer,radius)
	local pos = vector.round(player:getpos())
	local vm  = minetest.get_voxel_manip()
	local emin, emax
	local last_pos = cozyplayer.last_pos
	local distance = vector.distance(pos,last_pos)
	if distance < 20 then
		local pos1 = {
			x=pos.x < last_pos.x and pos.x or last_pos.x,
			y=pos.y < last_pos.y and pos.y or last_pos.y,
			z=pos.z < last_pos.z and pos.z or last_pos.z,
		}
		local pos2 = {
			x=pos.x > last_pos.x and pos.x or last_pos.x,
			y=pos.y > last_pos.y and pos.y or last_pos.y,
			z=pos.z > last_pos.z and pos.z or last_pos.z,
		}
		emin, emax = vm:read_from_map(vector.subtract(pos1, radius+1), vector.add(pos2, radius+1))
	else
		emin, emax = vm:read_from_map(vector.subtract(pos, radius+1), vector.add(pos, radius+1))
	end
	local data = vm:get_data()
	local a = VoxelArea:new{
		MinEdge = emin,
		MaxEdge = emax
	}
	local param2data = vm:get_param2_data()
	destroy_stale_wielded_light(data,param2data,a,cozyplayer)

	cozylights:setVoxelManipData(vm,data,nil,true)
end

local max_wield_light_radius = cozylights.max_wield_light_radius

function cozylights:set_wielded_light_radius(_radius)
	max_wield_light_radius = _radius
	minetest.settings:set("cozylights_wielded_light_radius",_radius)
	cozylights.max_wield_light_radius = _radius
end

function cozylights:draw_wielded_light(pos, last_pos, cozy_item,vel,cozyplayer,vm,a,data,param2data,emin,emax)
	local t = os.clock()
	local update_needed = 0
	local radius, dim_levels = cozylights:calc_dims(cozy_item)
	radius = radius > max_wield_light_radius and max_wield_light_radius or radius
	if radius == 0 then
		destroy_stale_wielded_light(data,param2data,a,cozyplayer)
		local node = minetest.get_node(pos)
		if node.name == "air" or string.match(node.name,"cozylights:") then
			local brightness_mod = cozy_item.modifiers ~= nil and cozylights.coziest_table[cozy_item.modifiers].brightness or 0
			local max_light = mf(cozy_item.light_source + cozylights.brightness_factor + brightness_mod) > 0 and mf(cozy_item.light_source + cozylights.brightness_factor + brightness_mod) or 0
			max_light = max_light > 14 and 14 or max_light
			local cid = minetest.get_content_id("cozylights:light"..max_light)
			if cid > minetest.get_content_id(node.name) then
				minetest.set_node(pos,{name="cozylights:light"..max_light,param2=node.param2})
				cozyplayer.prev_wielded_lights[#cozyplayer.prev_wielded_lights+1] = pos
			end
		else
			pos.y = pos.y - 1
			local n_name = minetest.get_node(pos).name
			if n_name == "air" or string.match(n_name,"cozylights:") then
				local brightness_mod = cozy_item.modifiers ~= nil and cozylights.coziest_table[cozy_item.modifiers].brightness or 0
				local max_light = mf(cozy_item.light_source + cozylights.brightness_factor + brightness_mod) > 0 and mf(cozy_item.light_source + cozylights.brightness_factor + brightness_mod) or 0
				max_light = max_light > 14 and 14 or max_light
				local cid = minetest.get_content_id("cozylights:light"..max_light)
				if cid > minetest.get_content_id(node.name) then
					minetest.set_node(pos,{name="cozylights:light"..max_light,param2=node.param2})
					cozyplayer.prev_wielded_lights[#cozyplayer.prev_wielded_lights+1] = pos
				end
			end
		end
		return
	end
	local possible_pos = vector.add(pos,vel)
	local node = minetest.get_node(possible_pos)
	if node.name == "air" or string.match(node.name, "cozylights:light") then
		pos = possible_pos
	end

	if vm == nil then
		vm = minetest.get_voxel_manip()
		local distance = vector.distance(pos,last_pos)
		if distance < 20 then
			local pos1 = {
				x=pos.x < last_pos.x and pos.x or last_pos.x,
				y=pos.y < last_pos.y and pos.y or last_pos.y,
				z=pos.z < last_pos.z and pos.z or last_pos.z,
			}
			local pos2 = {
				x=pos.x > last_pos.x and pos.x or last_pos.x,
				y=pos.y > last_pos.y and pos.y or last_pos.y,
				z=pos.z > last_pos.z and pos.z or last_pos.z,
			}
			emin, emax = vm:read_from_map(vector.subtract(pos1, radius+1), vector.add(pos2, radius+1))
		else
			emin, emax = vm:read_from_map(vector.subtract(pos, radius+1), vector.add(pos, radius+1))
		end
		data = vm:get_data()
		param2data = vm:get_param2_data()
		a = VoxelArea:new{
			MinEdge = emin,
			MaxEdge = emax
		}
		update_needed = 1
	end
	destroy_stale_wielded_light(data,param2data,a,cozyplayer)

	local c_light14 = c_lights[14]
	local sphere_surface = cozylights:get_sphere_surface(radius)
	local px = pos.x
	local py = pos.y
	local pz = pos.z
	local y_below = py - 1
	local y_above = py + 1
	local cidb = data[a:index(px,y_below,pz)]
	local cida = data[a:index(px,y_above,pz)]
	if cidb and cida then
		if (cidb == c_air or (cidb >= c_light1 and cidb <= c_light14))
			and cida ~= c_air and (cida < c_light1 or cida > c_light14)
		then
			py = py - 1
		end
	else
		return
	end
	local zstride, ystride = a.zstride, a.ystride
	local dirs = { -1*ystride, 1*ystride,-1,1,-1*zstride,1*zstride}
	for i,pos2 in ipairs(sphere_surface) do
		lightcast_lite(pos, vector.direction(pos,{x=px+pos2.x,y=py+pos2.y,z=pz+pos2.z}),dirs,radius,data,param2data,a,dim_levels,cozyplayer)
	end
	if update_needed == 1 then
		cozylights:setVoxelManipData(vm,data,param2data,true)
	end
	cozyplayer.last_wield_radius = radius
	gent_total = gent_total + mf((os.clock() - t) * 1000)
	gent_count = gent_count + 1
	--print("Average illum time " .. mf(gent_total/gent_count) .. " ms. Sample of: "..gent_count)
end

