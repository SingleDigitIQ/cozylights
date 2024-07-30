local sphere_surfaces = {[19]=nil}
local c_light1 = minetest.get_content_id("cozylights:light1")
local c_lights = { c_light1, c_light1 + 1, c_light1 + 2, c_light1 + 3, c_light1 + 4, c_light1 + 5, c_light1 + 6,
c_light1 + 7, c_light1 + 8, c_light1 + 9, c_light1 + 10, c_light1 + 11, c_light1 + 12, c_light1 + 13 }
local c_light14 = c_lights[14]
local c_light_debug1 = c_light14 + 1
local c_light_debug14 = c_light_debug1 + 13
local c_air = minetest.get_content_id("air")
local mf = math.floor

function cozylights:clear(pos,size)
	local t = os.clock()
	local minp,maxp,vm,data,param2data,a = cozylights:getVoxelManipData(pos,size)
	local count = 0
	for i in a:iterp(minp, maxp) do
		local cid = data[i]
		if cid >= c_light1 and cid <= c_light_debug14 then
			data[i] = c_air
			param2data[i] = 0
			count = count + 1
		end
	end
	minetest.chat_send_all("cleared "..count.." cozy light nodes in area around pos: "..cozylights:dump(pos).." of radius: "..size)
	if count> 0 then
		cozylights:setVoxelManipData(vm,data,param2data,true)
	end
	return (os.clock() - t)
end

function cozylights:getVoxelManipData(pos, size)
	local minp = vector.subtract(pos, size)
	local maxp = vector.add(pos, size)
	local vm  = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(vector.subtract(minp, 1), vector.add(maxp, 1))
	local data = vm:get_data()
	local param2data = vm:get_param2_data()
	local a = VoxelArea:new{
		MinEdge = emin,
		MaxEdge = emax
	}
	return minp,maxp,vm,data,param2data,a
end

function cozylights:setVoxelManipData(vm,data,param2data,update_liquids)
	vm:set_data(data)
	if param2data ~= nil then
		vm:set_param2_data(param2data)
	end
	if update_liquids == true then
		vm:update_liquids()
	end
	vm:write_to_map()
end

--todo: 6 directions of static slices or dynamic slices if its faster somehow(it wasnt so far)
function cozylights:slice_cake(surface,radius)
	local sliced = {}
	for k,v in pairs(surface) do
		-- full sphere except for a cone from center to max -y of 45 degrees or like pi/2 radians or something
		if v.y > -radius*0.7071 then
			table.insert(sliced,v)
		end
	end
	return sliced
end

-- radius*radius = x*x + y*y + z*z
function cozylights:get_sphere_surface(radius,sliced)
	if sphere_surfaces[radius] == nil then
		local sphere_surface = {}
		local rad_pow2_min, rad_pow2_max = radius * (radius - 1), radius * (radius + 1)
		for z = -radius, radius do
			for y = -radius, radius do
				for x = -radius, radius do
					local pow2 = x * x + y * y + z * z
					if pow2 >= rad_pow2_min and pow2 <= rad_pow2_max then
						-- todo: could arrange these in a more preferable for optimization order
						sphere_surface[#sphere_surface+1] = {x=x,y=y,z=z}
					end
				end
			end
		end
		local t = {
			full = sphere_surface
		}
		if radius < 30 then
			t.minusyslice = cozylights:slice_cake(sphere_surface,radius) --typical wielded light
			sphere_surfaces[radius] = t
			if sliced == true then
				return t.minusyslice
			end
		end
		return sphere_surface
	else
		if sliced == true and sphere_surfaces[radius].minusyslice ~= nil then
			return sphere_surfaces[radius].minusyslice
		end
		return sphere_surfaces[radius].full
	end
end

function cozylights:calc_dims(cozy_item)

	local brightness_mod = 0
	local reach_mod = 0
	local dim_mod = 0
	if cozy_item.modifiers ~= nil then
		brightness_mod = cozylights.coziest_table[cozy_item.modifiers].brightness
		reach_mod = cozylights.coziest_table[cozy_item.modifiers].reach_factor
		dim_mod = cozylights.coziest_table[cozy_item.modifiers].dim_factor
	end
	local max_light = mf(cozy_item.light_source + cozylights.brightness_factor + brightness_mod)
	local r = mf(max_light*max_light/10*(cozylights.reach_factor+reach_mod))
	--print("initial r: "..r)
	local r_max = 0
	local dim_levels = {}
	local dim_factor = cozylights.dim_factor + dim_mod
	for i = r , 1, -1 do
		local dim = math.sqrt(math.sqrt(i)) * dim_factor
		local light_i = max_light + 1 - mf(dim)
		if light_i < 1 then
			--light_i = 1
			r_max = i
		else
			if light_i > 14 then
				light_i = 14
			end
			dim_levels[i] = light_i
		end

	end
	-- we cut the r only if max_r found is lower than r, so that we keep the ability to have huge radiuses
	if r_max > 0 and r_max < r then
		return r_max-1,dim_levels
	end
	return r,dim_levels
end

local cozycids_sunlight_propagates = {}
-- ensure cozy position in memory
-- default amount of lights sources: 194
-- in default game with moreblocks mod: 5134
--cozylights:prealloc(cozycids_sunlight_propagates, 194, true)
--cozycids_sunlight_propagates = {}
minetest.after(1, function()
	cozycids_sunlight_propagates = cozylights.cozycids_sunlight_propagates
	cozylights:finalize(cozycids_sunlight_propagates)
	print(#cozycids_sunlight_propagates)
	cozylights.cozycids_sunlight_propagates = {}
	local version_welcome = minetest.settings:get("version_welcome")
	if version_welcome ~= cozylights.version then
		minetest.settings:set("version_welcome",cozylights.version)
		minetest.chat_send_all(">.< Running Cozy Lights "..cozylights.version.." alpha. Some features are still missing or might not work properly and might be fixed tomorrow or next week."..
		"\n>.< To learn more about what it can do check ContentDB page: https://content.minetest.net/packages/SingleDigitIQ/cozylights/"..
		"\n>.< If you experience problems, appreciate if you report them on ContentDB, Minetest forum, Github or Discord."..
		"\n>.< If you need more of original ideas and blazingly fast code in open source - leave a positive review on ContentDB or/and add to favorites."..
		"\n>.< To open mod settings type in chat /cozysettings or /zs, hopefully tooltips are useful."..
		"\n>.< This message displays only once per new downloaded update for Cozy Lights mod."..
		"\n>.< Have fun :>"
		)
	end
end)

-- adjusting dirfloor might help with some nodes missing. probably the only acceptable way to to eliminate node
-- misses and not sacrifice performance too much or at all
local dirfloor = 0.5
-- raycast but normal
-- todo: if radius higher than i think 15, we need to somehow grab more nodes, without it it's not entirely accurate
-- i hope a cheaply computed offset based on dir will do
-- not to forget: what i mean by that is that + 0.5 in mf has to become a variable

-- while we have the opportunity to cut the amount of same node reruns in this loop,
-- we avoid that because luajit optimization breaks with one more branch and hashtable look up
-- at least on my machine, and so it becomes slower to run and at the same time grabs more memory
-- todo: actually check for the forth time the above is real
function cozylights:lightcast(pos, dir, radius,data,param2data,a,dim_levels)
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	for i = 1, radius do
		local x,y,z = mf(dx*i+dirfloor)+px, mf(dy*i+dirfloor)+py, mf(dz*i+dirfloor)+pz
		local idx = a:index(x,y,z)
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			if cid == c_air or (cid >= c_light1 and cid <= c_light14) then
				local dim = (dim_levels[i] - light_nerf) >= 1 and (dim_levels[i] - light_nerf) or 1
				local light = c_lights[dim]
				if light > cid or param2data[idx] == 0 then
					data[idx] = light
					param2data[idx] = dim
				end
			else
				light_nerf = light_nerf + 1
			end
		else
			break
		end
	end
end

function cozylights:lightcast_erase(pos, dir, radius,data,param2data,a,dim_levels)
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	for i = 1, radius do
		local x,y,z = mf(dx*i+dirfloor)+px, mf(dy*i+dirfloor)+py, mf(dz*i+dirfloor)+pz
		local idx = a:index(x,y,z)
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			if cid >= c_light1 and cid <= c_light14 then
				local dim = (dim_levels[i] - light_nerf) >= 0 and (dim_levels[i] - light_nerf) or 0
				local light = dim > 0 and c_lights[dim] or c_air
				if light < cid then
					data[idx] = light
					param2data[idx] = dim
				end
			elseif cid ~= c_air then
				light_nerf = light_nerf + 1
			end
		else
			break
		end
	end
end

function cozylights:lightcast_override(pos, dir, radius,data,param2data,a,dim_levels)
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	for i = 1, radius do
		local x,y,z = mf(dx*i+dirfloor)+px, mf(dy*i+dirfloor)+py, mf(dz*i+dirfloor)+pz
		local idx = a:index(x,y,z)
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			if cid == c_air or (cid >= c_light1 and cid <= c_light14) then
				local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
				data[idx] = c_lights[dim]
				param2data[idx] = dim
			else
				light_nerf = light_nerf + 1
			end
		else
			break
		end
	end
end

function cozylights:lightcast_lighten(pos, dir, radius,data,param2data,a,dim_levels)
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	for i = 1, radius do
		local x,y,z = mf(dx*i+dirfloor)+px, mf(dy*i+dirfloor)+py, mf(dz*i+dirfloor)+pz
		local idx = a:index(x,y,z)
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			if cid == c_air or (cid >= c_light1 and cid <= c_light14) then
				local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
				if c_lights[dim] > cid then
					local original_light = cid - c_light1
					dim = mf((dim + original_light)/2+0.5)
					data[idx] = c_lights[dim]
					param2data[idx] = dim
				end
			else
				light_nerf = light_nerf + 1
			end
		else
			break
		end
	end
end

function cozylights:lightcast_darken(pos, dir, radius,data,param2data,a,dim_levels)
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	for i = 1, radius do
		local x,y,z = mf(dx*i+dirfloor)+px, mf(dy*i+dirfloor)+py, mf(dz*i+dirfloor)+pz
		local idx = a:index(x,y,z)
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			if cid >= c_light1 and cid <= c_light14 then
				local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
				if c_lights[dim] < cid then
					local original_light = cid - c_light1
					dim = mf((dim + original_light)/2)
					data[idx] = c_lights[dim]
					param2data[idx] = dim
				end
			elseif cid ~= c_air then
				light_nerf = light_nerf + 1
			end
		else
			break
		end
	end
end

function cozylights:lightcast_blend(pos, dir, radius,data,param2data,a,dim_levels)
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	for i = 1, radius do
		local x,y,z = mf(dx*i+dirfloor)+px, mf(dy*i+dirfloor)+py, mf(dz*i+dirfloor)+pz
		local idx = a:index(x,y,z)
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			if cid == c_air or (cid >= c_light1 and cid <= c_light14) then
				local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
				local original_light = cid - c_light1 --param2data[idx]
				dim = mf((dim + original_light)/2+0.5)
				if dim < 1 then break end
				data[idx] = c_lights[dim]
				param2data[idx] = dim
			else
				light_nerf = light_nerf + 1
			end
		else
			break
		end
	end
end

-- removes some lights that light up the opposite side of an obstacle
-- it is weird and inaccurate as of now, i can make it accurate the expensive way,
-- still looking for a cheap way
function cozylights:lightcast_fix_edges(pos, dir, radius,data,param2data,a,dim_levels,visited_pos)
	local dirs = { -1*a.ystride, 1*a.ystride,-1,1,-1*a.zstride,1*a.zstride}
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	local halfrad, braking_brak = radius/2, false
	local next_x, next_y, next_z = mf(dx+dirfloor) + px, mf(dy+dirfloor) + py, mf(dz+dirfloor) + pz
	for i = 1, radius,2 do
		local x,y,z = next_x, next_y, next_z
		local idx = a:index(x,y,z)
		for n = 1, 6 do
			if cozycids_sunlight_propagates[data[idx+dirs[n]]] == nil then
				braking_brak = true
				break
			end
		end
		if braking_brak == true then break end
		x,y,z = nil,nil,nil
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			-- appears that hash lookup in a loop is as bad as math
			if cid == c_air or (cid >= c_light1 and cid <= c_light14) then
				if i < halfrad then
					if not visited_pos[idx] then
						visited_pos[idx] = true
						local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
						local light = c_lights[dim]
						if light > cid or param2data[idx] == 0 then
							data[idx] = light
							param2data[idx] = dim
						end
					end
				else
					local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
					local light = c_lights[dim]
					if light > cid or param2data[idx] == 0 then
						data[idx] = light
						param2data[idx] = dim
					end
				end
			else
				light_nerf = light_nerf + 1
			end
		else
			break
		end
		next_x,next_y,next_z = mf(dx*(i+1)+dirfloor)+px, mf(dy*(i+1)+dirfloor)+py, mf(dz*(i+1)+dirfloor)+pz
		
		--local next_idx = a:index(next_x,next_y,next_z)
		--for n = 1, 6 do
		--	if cozycids_sunlight_propagates[data[next_idx+dirs[n]]] == nil then
		--		braking_brak = true
		--		break
		--	end
		--end
		--next_x,next_y,next_z = mf(dx*(i+2)+dirfloor)+px, mf(dy*(i+2)+dirfloor)+py, mf(dz*(i+2)+dirfloor)+pz
		
		--local next_adj_indxs = {
		--	a:index(next_x,y,z),
		--	a:index(x,y,next_z),
		--	a:index(x,next_y,z),
		--	a:index(next_x,next_y,z),
		--	a:index(x,next_y,next_z),
		--}

		--for _, j in pairs(next_adj_indxs) do
		--	if cozycids_sunlight_propagates[data[j]] ~= true then
		--		braking_brak = true
		--		break
		--	end
		--end

	end
end

function cozylights:lightcast_erase_fix_edges(pos, dir, radius,data,param2data,a,dim_levels,visited_pos)
	local dirs = { -1*a.ystride, 1*a.ystride,-1,1,-1*a.zstride,1*a.zstride}
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	local halfrad, braking_brak = radius/2, false
	local next_x, next_y, next_z = mf(dx+dirfloor) + px, mf(dy+dirfloor) + py, mf(dz+dirfloor) + pz
	for i = 1, radius do
		local x,y,z = next_x, next_y, next_z
		local idx = a:index(x,y,z)
		for n = 1, 6 do
			if cozycids_sunlight_propagates[data[idx+dirs[n]]] == nil then
				braking_brak = true
				break
			end
		end
		if braking_brak == true then break end
		x,y,z = nil,nil,nil
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			-- appears that hash lookup in a loop is as bad as math
			if cid >= c_light1 and cid <= c_light14 then
				if i < halfrad then
					if not visited_pos[idx] then
						visited_pos[idx] = true
						local dim = (dim_levels[i] - light_nerf) >= 0 and (dim_levels[i] - light_nerf) or 0
						local light = dim > 0 and c_lights[dim] or c_air
						if light < cid then
							data[idx] = light
							param2data[idx] = dim
						end
					end
				else
					local dim = (dim_levels[i] - light_nerf) >= 0 and (dim_levels[i] - light_nerf) or 0
					local light = dim > 0 and c_lights[dim] or c_air
					if light < cid then
						data[idx] = light
						param2data[idx] = dim
					end
				end
			elseif cid ~= c_air then
				light_nerf = light_nerf + 1
			end
		else
			break
		end
		next_x,next_y,next_z = mf(dx*(i+1)+dirfloor)+px, mf(dy*(i+1)+dirfloor)+py, mf(dz*(i+1)+dirfloor)+pz
	end
end

function cozylights:lightcast_override_fix_edges(pos, dir, radius,data,param2data,a,dim_levels,visited_pos)
	local dirs = { -1*a.ystride, 1*a.ystride,-1,1,-1*a.zstride,1*a.zstride}
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	local halfrad, braking_brak = radius/2, false
	local next_x, next_y, next_z = mf(dx+dirfloor) + px, mf(dy+dirfloor) + py, mf(dz+dirfloor) + pz
	for i = 1, radius do
		local x = next_x
		local y = next_y
		local z = next_z
		local idx = a:index(x,y,z)
		for n = 1, 6 do
			if cozycids_sunlight_propagates[data[idx+dirs[n]]] == nil then
				braking_brak = true
				break
			end
		end
		if braking_brak == true then break end
		x,y,z = nil,nil,nil -- they are probably still allocated though
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			-- appears that hash lookup in a loop is as bad as math
			if cid == c_air or (cid >= c_light1 and cid <= c_light14) then
				if i < halfrad then
					if not visited_pos[idx] then
						visited_pos[idx] = true
						local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
						data[idx] = c_lights[dim]
						param2data[idx] = dim
					end
				else
					local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
					data[idx] = c_lights[dim]
					param2data[idx] = dim
				end
			else
				light_nerf = light_nerf + 1
			end
		else
			break
		end
		next_x,next_y,next_z = mf(dx*(i+1)+dirfloor)+px, mf(dy*(i+1)+dirfloor)+py, mf(dz*(i+1)+dirfloor)+pz
	end
end


function cozylights:lightcast_lighten_fix_edges(pos, dir, radius,data,param2data,a,dim_levels,visited_pos)
	local dirs = { -1*a.ystride, 1*a.ystride,-1,1,-1*a.zstride,1*a.zstride}
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	local halfrad, braking_brak = radius/2, false
	local next_x, next_y, next_z = mf(dx+dirfloor) + px, mf(dy+dirfloor) + py, mf(dz+dirfloor) + pz
	for i = 1, radius do
		local x = next_x
		local y = next_y
		local z = next_z
		local idx = a:index(x,y,z)
		for n = 1, 6 do
			if cozycids_sunlight_propagates[data[idx+dirs[n]]] == nil then
				braking_brak = true
				break
			end
		end
		if braking_brak == true then break end
		x,y,z = nil,nil,nil -- they are probably still allocated though
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			-- appears that hash lookup in a loop is as bad as math
			if cid == c_air or (cid >= c_light1 and cid <= c_light14) then
				if i < halfrad then
					if not visited_pos[idx] then
						visited_pos[idx] = true
						local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
						if c_lights[dim] > cid then
							local original_light = cid - c_light1
							dim = mf((dim + original_light)/2+0.5)
							data[idx] = c_lights[dim]
							param2data[idx] = dim
						end
					end
				else
					local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
					if c_lights[dim] > cid then
						local original_light = cid - c_light1
						dim = mf((dim + original_light)/2+0.5)
						data[idx] = c_lights[dim]
						param2data[idx] = dim
					end
				end
			else
				light_nerf = light_nerf + 1
			end
		else
			break
		end
		next_x,next_y,next_z = mf(dx*(i+1)+dirfloor)+px, mf(dy*(i+1)+dirfloor)+py, mf(dz*(i+1)+dirfloor)+pz
	end
end


function cozylights:lightcast_darken_fix_edges(pos, dir, radius,data,param2data,a,dim_levels,visited_pos)
	local dirs = { -1*a.ystride, 1*a.ystride,-1,1,-1*a.zstride,1*a.zstride}
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	local halfrad, braking_brak = radius/2, false
	local next_x, next_y, next_z = mf(dx+dirfloor) + px, mf(dy+dirfloor) + py, mf(dz+dirfloor) + pz
	for i = 1, radius do
		local x = next_x
		local y = next_y
		local z = next_z
		local idx = a:index(x,y,z)
		for n = 1, 6 do
			if cozycids_sunlight_propagates[data[idx+dirs[n]]] == nil then
				braking_brak = true
				break
			end
		end
		if braking_brak == true then break end
		x,y,z = nil,nil,nil -- they are probably still allocated though
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			-- appears that hash lookup in a loop is as bad as math
			if cid == c_air or (cid >= c_light1 and cid <= c_light14) then
				if i < halfrad then
					if not visited_pos[idx] then
						visited_pos[idx] = true
						local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
						if c_lights[dim] < cid then
							local original_light = cid - c_light1
							dim = mf((dim + original_light)/2)
							data[idx] = c_lights[dim]
							param2data[idx] = dim
						end
					end
				else
					local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
					if c_lights[dim] < cid then
						local original_light = cid - c_light1
						dim = mf((dim + original_light)/2)
						data[idx] = c_lights[dim]
						param2data[idx] = dim
					end
				end
			else
				light_nerf = light_nerf + 1
			end
		else
			break
		end
		next_x,next_y,next_z = mf(dx*(i+1)+dirfloor)+px, mf(dy*(i+1)+dirfloor)+py, mf(dz*(i+1)+dirfloor)+pz
	end
end


function cozylights:lightcast_blend_fix_edges(pos, dir, radius,data,param2data,a,dim_levels,visited_pos)
	local dirs = { -1*a.ystride, 1*a.ystride,-1,1,-1*a.zstride,1*a.zstride}
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	local halfrad, braking_brak = radius/2, false
	local next_x, next_y, next_z = mf(dx+dirfloor) + px, mf(dy+dirfloor) + py, mf(dz+dirfloor) + pz
	for i = 1, radius do
		local x = next_x
		local y = next_y
		local z = next_z
		local idx = a:index(x,y,z)
		for n = 1, 6 do
			if cozycids_sunlight_propagates[data[idx+dirs[n]]] == nil then
				braking_brak = true
				break
			end
		end
		if braking_brak == true then break end
		x,y,z = nil,nil,nil -- they are probably still allocated though
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			-- appears that hash lookup in a loop is as bad as math
			if cid == c_air or (cid >= c_light1 and cid <= c_light14) then
				if i < halfrad then
					if not visited_pos[idx] then
						visited_pos[idx] = true
						local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
						local original_light = cid - c_light1
						dim = mf((dim + original_light)/2+0.5)
						if dim < 1 then break end
						data[idx] = c_lights[dim]
						param2data[idx] = dim
					end
				else
					local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
					local original_light = cid - c_light1
					dim = mf((dim + original_light)/2+0.5)
					if dim < 1 then break end
					data[idx] = c_lights[dim]
					param2data[idx] = dim
				end
			else
				light_nerf = light_nerf + 1
			end
		else
			break
		end
		next_x,next_y,next_z = mf(dx*(i+1)+dirfloor)+px, mf(dy*(i+1)+dirfloor)+py, mf(dz*(i+1)+dirfloor)+pz

	end
end