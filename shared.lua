local sphere_surfaces = { [19] = nil }
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
local c_light14 = c_lights[14]
local c_light_debug1 = c_light14 + 1
local c_light_debug14 = c_light_debug1 + 13
local c_air = minetest.get_content_id("air")
local mf = math.floor

function cozylights:clear(pos, size)
	local t = os.clock()
	local minp, maxp, vm, data, param2data, a = cozylights:getVoxelManipData(pos, size)
	local count = 0
	for i in a:iterp(minp, maxp) do
		local cid = data[i]
		if cid >= c_light1 and cid <= c_light_debug14 then
			data[i] = c_air
			param2data[i] = 0
			count = count + 1
		end
	end
	minetest.chat_send_all(
		"cleared "
			.. count
			.. " cozy light nodes in area around pos: "
			.. cozylights:dump(pos)
			.. " of radius: "
			.. size
	)
	if count > 0 then
		cozylights:setVoxelManipData(vm, data, param2data, true)
	end
	return (os.clock() - t)
end

function cozylights:getVoxelManipData(pos, size)
	local minp = vector.subtract(pos, size)
	local maxp = vector.add(pos, size)
	local vm = cozylights.get_voxel_manip()
	local emin, emax = vm:read_from_map(vector.subtract(minp, 1), vector.add(maxp, 1))
	local data = vm:get_data()
	local param2data = vm:get_param2_data()
	local a = VoxelArea:new({
		MinEdge = emin,
		MaxEdge = emax,
	})
	return minp, maxp, vm, data, param2data, a
end
cozylights.masked_mapblocks = cozylights.masked_mapblocks or {}
local floor = math.floor

function cozylights:setVoxelManipData(vm, data, param2data, update_liquids)
	vm:set_data(data)
	if param2data ~= nil then
		vm:set_param2_data(param2data)
	end
	if update_liquids == true then
		vm:update_liquids()
	end
	local emin, emax = vm:get_emerged_area()
	local min_x, min_y, min_z = floor(emin.x / 16), floor(emin.y / 16), floor(emin.z / 16)
	local max_x, max_y, max_z = floor(emax.x / 16), floor(emax.y / 16), floor(emax.z / 16)
	local mask = cozylights.masked_mapblocks
	for z = min_z, max_z do
		local z_hash = (z + 32768) * 4294967296 --65536*65536
		for y = min_y, max_y do
			local y_hash = z_hash + (y + 32768) * 65536
			for x = min_x, max_x do
				mask[y_hash + x + 32768] = true
			end
		end
	end
	vm:write_to_map()
end

--todo: 6 directions of static slices or dynamic slices if its faster somehow(it wasnt so far)
function cozylights:slice_cake(surface, radius)
	local sliced = {}
	for k, v in pairs(surface) do
		-- full sphere except for a cone from center to max -y of 45 degrees or like pi/2 radians or something
		if v.y > -radius * 0.7071 then
			table.insert(sliced, v)
		end
	end
	return sliced
end

-- radius*radius = x*x + y*y + z*z
function cozylights:get_sphere_surface(radius, sliced)
	if sphere_surfaces[radius] == nil then
		local sphere_surface = {}
		local rad_pow2_min, rad_pow2_max = radius * (radius - 1), radius * (radius + 1)
		for z = -radius, radius do
			for y = -radius, radius do
				for x = -radius, radius do
					local pow2 = x * x + y * y + z * z
					if pow2 >= rad_pow2_min and pow2 <= rad_pow2_max then
						-- todo: could arrange these in a more preferable for optimization order
						local len = math.sqrt(x * x + y * y + z * z)
						sphere_surface[#sphere_surface + 1] =
							{ x = x, y = y, z = z, nx = x / len, ny = y / len, nz = z / len }
					end
				end
			end
		end
		local t = {
			full = sphere_surface,
		}
		if radius < 30 then
			t.minusyslice = cozylights:slice_cake(sphere_surface, radius) --typical wielded light
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

cozylights.gradient_cache = {}
function cozylights:invalidate_gradient_cache()
	cozylights.gradient_cache = {}
end

function cozylights:calc_dims(item_name, cozy_item)
	local cached = cozylights.gradient_cache[item_name]
	if cached then
		return cached.radius, cached.dim_levels
	end
	local L = cozy_item.light_source or 0
	if L < 1 then
		L = 1
	elseif L > 14 then
		L = 14
	end
	local t = L / 14.0
	local strength = cozylights.global_strength * (t * (2.0 - t))
	strength = math.max(0, math.min(1, strength))
	local radius = math.max(1, math.floor(cozylights.global_radius * (t * t)))
	local brightness = L
	local dim_levels = {}
	local even = (strength >= 0.99)
	local scaled_strength = strength * 5.0
	local effective_radius = 1
	dim_levels[1] = brightness
	if not even then
		for i = 2, radius do
			local dim = math.sqrt(math.sqrt(i)) * (6.0 - scaled_strength)
			local light_i = math.floor(brightness - dim)
			if light_i > 0 then
				dim_levels[i] = light_i > 14 and 14 or light_i
				effective_radius = i
			else
				dim_levels[i] = 1
				effective_radius = i - 1
				break
			end
		end
	else
		for i = 2, radius do
			dim_levels[i] = brightness
		end
		effective_radius = radius
	end
	cozylights.gradient_cache[item_name] = {
		radius = effective_radius,
		dim_levels = dim_levels,
	}
	-- prealloc hack that is supposed to work
	cozylights:get_sphere_surface(effective_radius)
	if effective_radius < 30 then
		cozylights:get_sphere_surface(effective_radius, true)
	end
	return effective_radius, dim_levels
end

local cozycids_sunlight_propagates = {}
-- attempt cozy position
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
		minetest.settings:set("version_welcome", cozylights.version)
		minetest.chat_send_all(
			">.< Running Cozy Lights "
				.. cozylights.version
				.. " alpha. Some features are still missing or might not work properly and might be fixed later."
				.. "\n>.< To learn more about what it can do check ContentDB page: https://content.minetest.net/packages/SingleDigitIQ/cozylights/"
				.. "\n>.< If you experience problems, appreciate if you report them on ContentDB, Minetest forum, Github or Discord."
				.. "\n>.< If you need more of original ideas and blazingly fast code in open source - leave a positive review on ContentDB or/and add to favorites."
				.. "\n>.< To open mod settings type in chat /cozysettings or /zs, hopefully tooltips are useful."
				.. "\n>.< This message displays only once per new downloaded update for Cozy Lights mod."
				.. "\n>.< Have fun :>"
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
function cozylights:lightcast(pos, dir, radius, data, param2data, a, dim_levels)
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	for i = 1, radius do
		local x, y, z = mf(dx * i + dirfloor) + px, mf(dy * i + dirfloor) + py, mf(dz * i + dirfloor) + pz
		local idx = a:index(x, y, z)
		local cid = data[idx]
		local is_origin = (x == px and y == py and z == pz)
		if cozycids_sunlight_propagates[cid] == true and not is_origin then
			if cid == c_air or (cid >= c_light1 and cid <= c_light_debug14) then
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

function cozylights:lightcast_erase(pos, dir, radius, data, param2data, a, dim_levels)
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	for i = 1, radius do
		local x, y, z = mf(dx * i + dirfloor) + px, mf(dy * i + dirfloor) + py, mf(dz * i + dirfloor) + pz
		local idx = a:index(x, y, z)
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			if cid >= c_light1 and cid <= c_light_debug14 then
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

function cozylights:lightcast_override(pos, dir, radius, data, param2data, a, dim_levels)
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	for i = 1, radius do
		local x, y, z = mf(dx * i + dirfloor) + px, mf(dy * i + dirfloor) + py, mf(dz * i + dirfloor) + pz
		local idx = a:index(x, y, z)
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			if cid == c_air or (cid >= c_light1 and cid <= c_light_debug14) then
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

function cozylights:lightcast_lighten(pos, dir, radius, data, param2data, a, dim_levels)
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	for i = 1, radius do
		local x, y, z = mf(dx * i + dirfloor) + px, mf(dy * i + dirfloor) + py, mf(dz * i + dirfloor) + pz
		local idx = a:index(x, y, z)
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			if cid == c_air or (cid >= c_light1 and cid <= c_light_debug14) then
				local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
				if c_lights[dim] > cid then
					local original_light = cid - c_light1
					dim = mf((dim + original_light) / 2 + 0.5)
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

function cozylights:lightcast_darken(pos, dir, radius, data, param2data, a, dim_levels)
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	for i = 1, radius do
		local x, y, z = mf(dx * i + dirfloor) + px, mf(dy * i + dirfloor) + py, mf(dz * i + dirfloor) + pz
		local idx = a:index(x, y, z)
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			if cid >= c_light1 and cid <= c_light_debug14 then
				local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
				if c_lights[dim] < cid then
					local original_light = cid - c_light1
					dim = mf((dim + original_light) / 2)
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

function cozylights:lightcast_blend(pos, dir, radius, data, param2data, a, dim_levels)
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	for i = 1, radius do
		local x, y, z = mf(dx * i + dirfloor) + px, mf(dy * i + dirfloor) + py, mf(dz * i + dirfloor) + pz
		local idx = a:index(x, y, z)
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			if cid == c_air or (cid >= c_light1 and cid <= c_light_debug14) then
				local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
				local original_light = cid - c_light1 --param2data[idx]
				dim = mf((dim + original_light) / 2 + 0.5)
				if dim < 1 then
					break
				end
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

function cozylights:lightcast_fix_edges(pos, dir, radius, data, param2data, a, dim_levels, visited_pos)
	local px, py, pz = pos.x, pos.y, pos.z
	local dx, dy, dz = dir.x, dir.y, dir.z
	local stepX = dx > 0 and 1 or (dx < 0 and -1 or 0)
	local stepY = dy > 0 and 1 or (dy < 0 and -1 or 0)
	local stepZ = dz > 0 and 1 or (dz < 0 and -1 or 0)
	local tDeltaX = stepX ~= 0 and math.abs(1 / dx) or math.huge
	local tDeltaY = stepY ~= 0 and math.abs(1 / dy) or math.huge
	local tDeltaZ = stepZ ~= 0 and math.abs(1 / dz) or math.huge
	local tMaxX = stepX ~= 0 and 0.5 * tDeltaX or math.huge
	local tMaxY = stepY ~= 0 and 0.5 * tDeltaY or math.huge
	local tMaxZ = stepZ ~= 0 and 0.5 * tDeltaZ or math.huge
	local x, y, z = px, py, pz
	local light_nerf = 0
	local halfrad = radius * 0.5
	for step = 1, radius * 3 do
		local dist = (x - px) * dx + (y - py) * dy + (z - pz) * dz
		local i = math.floor(dist + 0.5)
		if i < 1 then
			i = 1
		end
		if i > radius then
			break
		end
		local idx = a:index(x, y, z)
		local cid = data[idx]

		local is_origin = (x == px and y == py and z == pz)
		if not cozycids_sunlight_propagates[cid] and not is_origin then
			break
		end
		if cid == c_air or (cid >= c_light1 and cid <= c_light_debug14) then
			local dim = dim_levels[i] - light_nerf
			dim = dim > 0 and dim or 1
			local light = c_lights[dim]
			if i < halfrad then
				if not visited_pos[idx] then
					visited_pos[idx] = true
					if light > cid or param2data[idx] == 0 then
						data[idx] = light
						param2data[idx] = dim
					end
				end
			else
				if light > cid or param2data[idx] == 0 then
					data[idx] = light
					param2data[idx] = dim
				end
			end
		elseif is_origin then
		-- do literally nothing, this branch in hot loop is so lame
		else
			light_nerf = light_nerf + 1
		end
		if tMaxX < tMaxY then
			if tMaxX < tMaxZ then
				x = x + stepX
				tMaxX = tMaxX + tDeltaX
			else
				z = z + stepZ
				tMaxZ = tMaxZ + tDeltaZ
			end
		else
			if tMaxY < tMaxZ then
				y = y + stepY
				tMaxY = tMaxY + tDeltaY
			else
				z = z + stepZ
				tMaxZ = tMaxZ + tDeltaZ
			end
		end
	end
end

function cozylights:lightcast_erase_fix_edges(pos, dir, radius, data, param2data, a, dim_levels, visited_pos)
	local dirs = { -1 * a.ystride, 1 * a.ystride, -1, 1, -1 * a.zstride, 1 * a.zstride }
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	local halfrad, braking_brak = radius / 2, false
	local next_x, next_y, next_z = mf(dx + dirfloor) + px, mf(dy + dirfloor) + py, mf(dz + dirfloor) + pz
	for i = 1, radius do
		local x, y, z = next_x, next_y, next_z
		local idx = a:index(x, y, z)
		for n = 1, 6 do
			if cozycids_sunlight_propagates[data[idx + dirs[n]]] == nil then
				braking_brak = true
				break
			end
		end
		if braking_brak == true then
			break
		end
		x, y, z = nil, nil, nil
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			-- appears that hash lookup in a loop is as bad as math
			if cid >= c_light1 and cid <= c_light_debug14 then
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
		next_x, next_y, next_z =
			mf(dx * (i + 1) + dirfloor) + px, mf(dy * (i + 1) + dirfloor) + py, mf(dz * (i + 1) + dirfloor) + pz
	end
end

function cozylights:lightcast_override_fix_edges(pos, dir, radius, data, param2data, a, dim_levels, visited_pos)
	local dirs = { -1 * a.ystride, 1 * a.ystride, -1, 1, -1 * a.zstride, 1 * a.zstride }
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	local halfrad, braking_brak = radius / 2, false
	local next_x, next_y, next_z = mf(dx + dirfloor) + px, mf(dy + dirfloor) + py, mf(dz + dirfloor) + pz
	for i = 1, radius do
		local x = next_x
		local y = next_y
		local z = next_z
		local idx = a:index(x, y, z)
		for n = 1, 6 do
			if cozycids_sunlight_propagates[data[idx + dirs[n]]] == nil then
				braking_brak = true
				break
			end
		end
		if braking_brak == true then
			break
		end
		x, y, z = nil, nil, nil -- they are probably still allocated though
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			-- appears that hash lookup in a loop is as bad as math
			if cid == c_air or (cid >= c_light1 and cid <= c_light_debug14) then
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
		next_x, next_y, next_z =
			mf(dx * (i + 1) + dirfloor) + px, mf(dy * (i + 1) + dirfloor) + py, mf(dz * (i + 1) + dirfloor) + pz
	end
end

function cozylights:lightcast_lighten_fix_edges(pos, dir, radius, data, param2data, a, dim_levels, visited_pos)
	local dirs = { -1 * a.ystride, 1 * a.ystride, -1, 1, -1 * a.zstride, 1 * a.zstride }
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	local halfrad, braking_brak = radius / 2, false
	local next_x, next_y, next_z = mf(dx + dirfloor) + px, mf(dy + dirfloor) + py, mf(dz + dirfloor) + pz
	for i = 1, radius do
		local x = next_x
		local y = next_y
		local z = next_z
		local idx = a:index(x, y, z)
		for n = 1, 6 do
			if cozycids_sunlight_propagates[data[idx + dirs[n]]] == nil then
				braking_brak = true
				break
			end
		end
		if braking_brak == true then
			break
		end
		x, y, z = nil, nil, nil -- they are probably still allocated though
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			-- appears that hash lookup in a loop is as bad as math
			if cid == c_air or (cid >= c_light1 and cid <= c_light_debug14) then
				if i < halfrad then
					if not visited_pos[idx] then
						visited_pos[idx] = true
						local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
						if c_lights[dim] > cid then
							local original_light = cid - c_light1
							dim = mf((dim + original_light) / 2 + 0.5)
							data[idx] = c_lights[dim]
							param2data[idx] = dim
						end
					end
				else
					local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
					if c_lights[dim] > cid then
						local original_light = cid - c_light1
						dim = mf((dim + original_light) / 2 + 0.5)
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
		next_x, next_y, next_z =
			mf(dx * (i + 1) + dirfloor) + px, mf(dy * (i + 1) + dirfloor) + py, mf(dz * (i + 1) + dirfloor) + pz
	end
end

function cozylights:lightcast_darken_fix_edges(pos, dir, radius, data, param2data, a, dim_levels, visited_pos)
	local dirs = { -1 * a.ystride, 1 * a.ystride, -1, 1, -1 * a.zstride, 1 * a.zstride }
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	local halfrad, braking_brak = radius / 2, false
	local next_x, next_y, next_z = mf(dx + dirfloor) + px, mf(dy + dirfloor) + py, mf(dz + dirfloor) + pz
	for i = 1, radius do
		local x = next_x
		local y = next_y
		local z = next_z
		local idx = a:index(x, y, z)
		for n = 1, 6 do
			if cozycids_sunlight_propagates[data[idx + dirs[n]]] == nil then
				braking_brak = true
				break
			end
		end
		if braking_brak == true then
			break
		end
		x, y, z = nil, nil, nil -- they are probably still allocated though
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			-- appears that hash lookup in a loop is as bad as math
			if cid == c_air or (cid >= c_light1 and cid <= c_light_debug14) then
				if i < halfrad then
					if not visited_pos[idx] then
						visited_pos[idx] = true
						local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
						if c_lights[dim] < cid then
							local original_light = cid - c_light1
							dim = mf((dim + original_light) / 2)
							data[idx] = c_lights[dim]
							param2data[idx] = dim
						end
					end
				else
					local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
					if c_lights[dim] < cid then
						local original_light = cid - c_light1
						dim = mf((dim + original_light) / 2)
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
		next_x, next_y, next_z =
			mf(dx * (i + 1) + dirfloor) + px, mf(dy * (i + 1) + dirfloor) + py, mf(dz * (i + 1) + dirfloor) + pz
	end
end

function cozylights:lightcast_blend_fix_edges(pos, dir, radius, data, param2data, a, dim_levels, visited_pos)
	local dirs = { -1 * a.ystride, 1 * a.ystride, -1, 1, -1 * a.zstride, 1 * a.zstride }
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local light_nerf = 0
	local halfrad, braking_brak = radius / 2, false
	local next_x, next_y, next_z = mf(dx + dirfloor) + px, mf(dy + dirfloor) + py, mf(dz + dirfloor) + pz
	for i = 1, radius do
		local x = next_x
		local y = next_y
		local z = next_z
		local idx = a:index(x, y, z)
		for n = 1, 6 do
			if cozycids_sunlight_propagates[data[idx + dirs[n]]] == nil then
				braking_brak = true
				break
			end
		end
		if braking_brak == true then
			break
		end
		x, y, z = nil, nil, nil -- they are probably still allocated though
		local cid = data[idx]
		if cozycids_sunlight_propagates[cid] == true then
			-- appears that hash lookup in a loop is as bad as math
			if cid == c_air or (cid >= c_light1 and cid <= c_light_debug14) then
				if i < halfrad then
					if not visited_pos[idx] then
						visited_pos[idx] = true
						local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
						local original_light = cid - c_light1
						dim = mf((dim + original_light) / 2 + 0.5)
						if dim < 1 then
							break
						end
						data[idx] = c_lights[dim]
						param2data[idx] = dim
					end
				else
					local dim = (dim_levels[i] - light_nerf) > 0 and (dim_levels[i] - light_nerf) or 1
					local original_light = cid - c_light1
					dim = mf((dim + original_light) / 2 + 0.5)
					if dim < 1 then
						break
					end
					data[idx] = c_lights[dim]
					param2data[idx] = dim
				end
			else
				light_nerf = light_nerf + 1
			end
		else
			break
		end
		next_x, next_y, next_z =
			mf(dx * (i + 1) + dirfloor) + px, mf(dy * (i + 1) + dirfloor) + py, mf(dz * (i + 1) + dirfloor) + pz
	end
end
function cozylights:shadowcast_fix_edges(pos, dir, radius, data, param2data, a, pos_placed)
	local px, py, pz = pos.x, pos.y, pos.z
	local dx, dy, dz = dir.x, dir.y, dir.z
	local stepX = dx > 0 and 1 or (dx < 0 and -1 or 0)
	local stepY = dy > 0 and 1 or (dy < 0 and -1 or 0)
	local stepZ = dz > 0 and 1 or (dz < 0 and -1 or 0)
	local tDeltaX = stepX ~= 0 and math.abs(1 / dx) or math.huge
	local tDeltaY = stepY ~= 0 and math.abs(1 / dy) or math.huge
	local tDeltaZ = stepZ ~= 0 and math.abs(1 / dz) or math.huge
	local tMaxX = stepX ~= 0 and 0.5 * tDeltaX or math.huge
	local tMaxY = stepY ~= 0 and 0.5 * tDeltaY or math.huge
	local tMaxZ = stepZ ~= 0 and 0.5 * tDeltaZ or math.huge
	local x, y, z = px, py, pz
	local passed_obstruction = false
	for step = 1, radius * 3 do
		local dist = (x - px) * dx + (y - py) * dy + (z - pz) * dz
		local i = math.floor(dist + 0.5)
		if i < 1 then
			i = 1
		end
		if i > radius then
			break
		end
		if x == pos_placed.x and y == pos_placed.y and z == pos_placed.z then
			passed_obstruction = true
		else
			local idx = a:index(x, y, z)
			local cid = data[idx]

			local is_origin = (x == px and y == py and z == pz)
			if not cozycids_sunlight_propagates[cid] and not is_origin then
				break
			end
			if passed_obstruction and cid >= c_light1 and cid <= c_light_debug14 then
				data[idx] = c_air
				param2data[idx] = 0
			end
		end
		if tMaxX < tMaxY then
			if tMaxX < tMaxZ then
				x = x + stepX
				tMaxX = tMaxX + tDeltaX
			else
				z = z + stepZ
				tMaxZ = tMaxZ + tDeltaZ
			end
		else
			if tMaxY < tMaxZ then
				y = y + stepY
				tMaxY = tMaxY + tDeltaY
			else
				z = z + stepZ
				tMaxZ = tMaxZ + tDeltaZ
			end
		end
	end
end

function cozylights:shadowcast(pos, dir, radius, data, param2data, a, pos_placed)
	local px, py, pz = pos.x, pos.y, pos.z
	local dx, dy, dz = dir.x, dir.y, dir.z
	local passed_obstruction = false
	for i = 1, radius do
		local x = math.floor(dx * i + dirfloor) + px
		local y = math.floor(dy * i + dirfloor) + py
		local z = math.floor(dz * i + dirfloor) + pz
		if x == pos_placed.x and y == pos_placed.y and z == pos_placed.z then
			passed_obstruction = true
		else
			local idx = a:index(x, y, z)
			local cid = data[idx]
			local is_origin = (x == px and y == py and z == pz)
			if not cozycids_sunlight_propagates[cid] and not is_origin then
				break
			end
			if passed_obstruction and cid >= c_light1 and cid <= c_light_debug14 then
				data[idx] = c_air
				param2data[idx] = 0
			end
		end
	end
end

function cozylights:update_shadow_cone(pos_placed)
	local t = os.clock()
	local max_bound = 15
	for bound, _ in pairs(cozylights.rebuild_bounds) do
		if bound > max_bound then
			max_bound = bound
		end
	end
	local s_minp = vector.subtract(pos_placed, max_bound)
	local s_maxp = vector.add(pos_placed, max_bound)
	local nearby_lights = cozylights.storage.get_lights_in_area(s_minp, s_maxp)
	local occluded_lights = {}
	for i = 1, #nearby_lights do
		local l_data = nearby_lights[i]
		if l_data.generated then
			local V_a = vector.subtract(pos_placed, l_data.pos)
			local D_sq = V_a.x * V_a.x + V_a.y * V_a.y + V_a.z * V_a.z
			if D_sq <= l_data.radius * l_data.radius and D_sq > 0 then
				occluded_lights[#occluded_lights + 1] = {
					pos = l_data.pos,
					radius = l_data.radius,
				}
			end
		end
	end
	if #occluded_lights == 0 then
		return
	end
	local min_read = { x = pos_placed.x, y = pos_placed.y, z = pos_placed.z }
	local max_read = { x = pos_placed.x, y = pos_placed.y, z = pos_placed.z }
	local active_casts = {}
	local VOXEL_SQ_RADIUS = (math.sqrt(3) / 2) ^ 2 * 1.5
	for i = 1, #occluded_lights do
		local source_pos = occluded_lights[i].pos
		local radius = occluded_lights[i].radius
		local node_below = minetest.get_node({ x = source_pos.x, y = source_pos.y - 1, z = source_pos.z }).name
		local node_above = minetest.get_node({ x = source_pos.x, y = source_pos.y + 1, z = source_pos.z }).name
		local ylvl = 1
		if node_below == "air" and node_above ~= "air" then
			ylvl = -1
		end
		local adj_source = { x = source_pos.x, y = source_pos.y + ylvl, z = source_pos.z }
		local V_a = vector.subtract(pos_placed, adj_source)
		local D_sq = V_a.x * V_a.x + V_a.y * V_a.y + V_a.z * V_a.z
		local D = math.sqrt(D_sq)
		local ux, uy, uz = V_a.x / D, V_a.y / D, V_a.z / D
		local cos_theta
		if #occluded_lights == 1 then
			cos_theta = 1.0 - (VOXEL_SQ_RADIUS / (2 * D_sq))
		else
			cos_theta = (D_sq > 3.0) and (math.sqrt(D_sq - 3.0) / D) or -1.0
		end
		local sphere_surface = cozylights:get_sphere_surface(radius)
		local valid_targets = {}
		for j = 1, #sphere_surface do
			local target = sphere_surface[j]
			local dot = ux * target.nx + uy * target.ny + uz * target.nz
			if dot >= cos_theta then
				valid_targets[#valid_targets + 1] = target
				local ex = adj_source.x + target.x
				local ey = adj_source.y + target.y
				local ez = adj_source.z + target.z
				min_read.x = math.min(min_read.x, adj_source.x, ex)
				max_read.x = math.max(max_read.x, adj_source.x, ex)
				min_read.y = math.min(min_read.y, adj_source.y, ey)
				max_read.y = math.max(max_read.y, adj_source.y, ey)
				min_read.z = math.min(min_read.z, adj_source.z, ez)
				max_read.z = math.max(max_read.z, adj_source.z, ez)
			end
		end
		active_casts[#active_casts + 1] = {
			adj_source = adj_source,
			radius = radius,
			targets = valid_targets,
		}
	end
	if #active_casts == 0 then
		return
	end
	min_read.x, min_read.y, min_read.z = min_read.x - 1, min_read.y - 1, min_read.z - 1
	max_read.x, max_read.y, max_read.z = max_read.x + 1, max_read.y + 1, max_read.z + 1
	local vm = cozylights.get_voxel_manip()
	local emin, emax = vm:read_from_map(min_read, max_read)
	local data = vm:get_data()
	local param2data = vm:get_param2_data()
	local a = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local use_fix_edges = cozylights.always_fix_edges
	local visited_pos = use_fix_edges and {} or nil
	for i = 1, #active_casts do
		local cast = active_casts[i]
		local targets = cast.targets
		for j = 1, #targets do
			local target = targets[j]
			local end_pos = {
				x = cast.adj_source.x + target.x,
				y = cast.adj_source.y + target.y,
				z = cast.adj_source.z + target.z,
			}
			local dir = vector.direction(cast.adj_source, end_pos)
			if use_fix_edges then
				cozylights:shadowcast_fix_edges(cast.adj_source, dir, cast.radius, data, param2data, a, pos_placed)
			else
				cozylights:shadowcast(cast.adj_source, dir, cast.radius, data, param2data, a, pos_placed)
			end
		end
	end
	cozylights:setVoxelManipData(vm, data, param2data, true)
	print("Shadow cone update time: " .. math.floor((os.clock() - t) * 1000) .. " ms")
end
