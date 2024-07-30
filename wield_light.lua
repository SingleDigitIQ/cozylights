local c_air = minetest.get_content_id("air")
local c_light1 = minetest.get_content_id("cozylights:light1")

local c_lights = { c_light1, c_light1 + 1, c_light1 + 2, c_light1 + 3, c_light1 + 4, c_light1 + 5, c_light1 + 6,
	c_light1 + 7, c_light1 + 8, c_light1 + 9, c_light1 + 10, c_light1 + 11, c_light1 + 12, c_light1 + 13 }

local gent_total = 0
local gent_count = 0
local mf = math.floor
--local cozycids_sunlight_propagates = cozylights.cozycids_sunlight_propagates

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

--ffi.cdef([[
--typedef struct {float x, y, z;} v3float;
--typedef struct {int16_t x, y, z;} v3;
--typedef struct {uint16_t* data; uint8_t* param2data;} vm_data;
--vm_data l_ttt(
--	v3* sphere_surface, int sphere_surface_length, v3 pos, v3 minp, v3 maxp, uint16_t radius, uint16_t* data, uint8_t* param2data,
--	uint8_t* dim_levels, bool* cozycids_sunlight, int c_air, uint16_t* c_lights
--);
--]])
--local ctest = ffi.load(cozylights.modpath.."/liblight.so")

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
	--[[--cdata experiments, so if we offload heavy lifting on c, it will actually be slower by 20%
		--not even a bit faster, so i d rather not continue on this
		--because vm:set_data works with lua state and expects lua table,
		--and interpreting c types back to lua table seems to be ridiculously expensive to bother
		--basically lua is useless and helpless without lua state
	minetest.chat_send_all("jit.status() "..cozylights:dump(jit.status()))
	local csphere_surface = ffi.new("v3struct["..(#sphere_surface+1).."]", sphere_surface)
	local cpos = ffi.new("v3struct", pos)
	local cemin = ffi.new("v3struct",emin)
	local cemax = ffi.new("v3struct",emax)
	local cradius = ffi.new("int",radius)
	local testcdata = ffi.new("uint16_t["..(#data).."]")
	local cdim_levels = ffi.new("uint16_t["..(#dim_levels+1).."]", dim_levels)
	local cc_air = 	ffi.new("int",c_air)
	local cc_lights = ffi.new("uint16_t["..(#c_lights+1).."]", c_lights)
	for i = 1, #data do
		testcdata[i-1] = ffi.new("uint16_t",data[i])
	end
	local cparam2data = ffi.new("uint16_t["..#param2data.."]")
	for i = 1, #param2data do
		cparam2data[i-1] = ffi.new("uint16_t",param2data[i])
	end
	local ccozycids = ffi.new("bool["..#cozycids_sunlight_propagates.."]",cozycids_sunlight_propagates)
	local length = ffi.new("int",#sphere_surface)
	local idk = (ctest.l_ttt(csphere_surface,length, cpos,cemin,cemax,cradius,testcdata,cparam2data,cdim_levels,ccozycids,cc_air,cc_lights))
	idk = idk.data
	if idk ~= nil then
		for i=0,#data do
			local incoming = tonumber(idk[i])
			if data[i+1] ~= incoming then
				data[i+1] = incoming
				table.insert(cozyplayer.prev_wielded_lights, a:position(i+1))
			end
		end
	end
	for i = 1, #param2data do
		param2data[i] = tonumber(cparam2data[i-1])
	end]]

	for i,pos2 in ipairs(sphere_surface) do
		lightcast_lite(pos, vector.direction(pos,{x=px+pos2.x,y=py+pos2.y,z=pz+pos2.z}),dirs,radius,data,param2data,a,dim_levels,cozyplayer)
	end
	if update_needed == 1 then
		cozylights:setVoxelManipData(vm,data,param2data,true)
	end
	cozyplayer.last_wield_radius = radius
	gent_total = gent_total + mf((os.clock() - t) * 1000)
	gent_count = gent_count + 1
	print("Av wield illum time " .. mf(gent_total/gent_count) .. " ms. Sample of: "..gent_count)
end

