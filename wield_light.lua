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
local mf = math.floor

local ray_caches = {}
local function build_ray_cache(radius, dim_levels)
	if ray_caches[radius] then
		return ray_caches[radius]
	end
	local surface = cozylights:get_sphere_surface(radius)
	local cache = {}
	for i = 1, #surface do
		local ray = {}
		local pos2 = surface[i]
		local len = math.sqrt(pos2.x * pos2.x + pos2.y * pos2.y + pos2.z * pos2.z)
		local nx, ny, nz = pos2.x / len, pos2.y / len, pos2.z / len
		local pointer = 1
		for r = 1, radius do
			ray[pointer] = mf(nx * r + 0.5)
			ray[pointer + 1] = mf(ny * r + 0.5)
			ray[pointer + 2] = mf(nz * r + 0.5)
			ray[pointer + 3] = dim_levels[r] or 1
			pointer = pointer + 4
		end
		cache[i] = ray
	end
	ray_caches[radius] = cache
	return cache
end

local function destroy_stale_wielded_light(data, param2data, a, cozyplayer)
	local c_light14 = c_lights[14]
	if not cozyplayer.prev_wielded_lights then
		return
	end
	for j, p in ipairs(cozyplayer.prev_wielded_lights) do
		local idx = a:index(p.x, p.y, p.z)
		if data[idx] == p.placed_cid and param2data[idx] == p.old_p2 then
			data[idx] = p.old_cid
		else
			local cid = data[idx]
			if cid >= c_light1 and cid <= c_light14 then
				local anchor = param2data[idx]
				if anchor > 0 and anchor <= 14 then
					data[idx] = c_light1 + anchor - 1
				else
					data[idx] = c_air
				end
			end
		end
	end
	cozyplayer.prev_wielded_lights = {}
end

function cozylights:wielded_light_cleanup(player, cozyplayer, radius)
	if cozyplayer.prev_wielded_lights then
		for j, p in ipairs(cozyplayer.prev_wielded_lights) do
			local node = cozylights.get_node({ x = p.x, y = p.y, z = p.z })
			local placed_name = minetest.get_name_from_content_id(p.placed_cid) or "air"
			if node.name == placed_name and node.param2 == p.old_p2 then
				local old_name = minetest.get_name_from_content_id(p.old_cid) or "air"
				minetest.swap_node({ x = p.x, y = p.y, z = p.z }, { name = old_name, param2 = p.old_p2 })
			else
				if string.sub(node.name, 1, 16) == "cozylights:light" then
					local anchor = node.param2
					if anchor > 0 and anchor <= 14 then
						minetest.swap_node(
							{ x = p.x, y = p.y, z = p.z },
							{ name = "cozylights:light" .. anchor, param2 = anchor }
						)
					else
						minetest.swap_node({ x = p.x, y = p.y, z = p.z }, { name = "air" })
					end
				end
			end
		end
		cozyplayer.prev_wielded_lights = {}
	end
	local last_pos = cozyplayer.last_pos
	local last_rad = cozyplayer.last_wield_radius
	if last_pos and last_rad and last_rad > 0 then
		local r = last_rad + 14
		local fix_min = vector.subtract(last_pos, r)
		local fix_max = vector.add(last_pos, r)
		minetest.fix_light(fix_min, fix_max)
	end
	cozyplayer.last_wield_radius = nil
	cozyplayer.last_hard_sync_pos = nil
end

local max_wield_light_radius = cozylights.max_wield_light_radius

function cozylights:set_wielded_light_radius(_radius)
	max_wield_light_radius = _radius
	minetest.settings:set("cozylights_wielded_light_radius", _radius)
	cozylights.max_wield_light_radius = _radius
end

function cozylights:draw_wielded_light(
	pos,
	last_pos,
	cozy_item,
	vel,
	cozyplayer,
	wield_name,
	vm,
	a,
	data,
	param2data,
	emin,
	emax
)
	local t = os.clock()
	local radius, dim_levels = cozylights:calc_dims(wield_name, cozy_item)
	radius = radius > max_wield_light_radius and max_wield_light_radius or radius
	local brightness_mod = cozy_item.modifiers ~= nil and cozylights.coziest_table[cozy_item.modifiers].brightness or 0
	if last_pos and vector.distance(pos, last_pos) > 32 then
		if cozyplayer.prev_wielded_lights and #cozyplayer.prev_wielded_lights > 0 then
			cozylights:wielded_light_cleanup(nil, cozyplayer, radius)
		end
	end

	local max_light = mf(cozy_item.light_source + cozylights.brightness_factor + brightness_mod)
	max_light = math.max(1, math.min(14, max_light))
	local nat_light = minetest.get_natural_light(pos)
	local last_nat = max_light
	if cozyplayer.last_pos then
		last_nat = minetest.get_natural_light(cozyplayer.last_pos) or max_light
	end
	if nat_light and nat_light >= max_light and last_nat >= max_light then
		if cozyplayer.prev_wielded_lights and #cozyplayer.prev_wielded_lights > 0 then
			cozylights:wielded_light_cleanup(nil, cozyplayer, radius)
		end
		return
	end
	local ray_cache = build_ray_cache(radius, dim_levels)
	if radius == 0 then
		local new_name = "cozylights:light" .. max_light
		local new_cid = minetest.get_content_id(new_name)
		if
			cozyplayer.last_wield_radius == 0
			and cozyplayer.prev_wielded_lights
			and #cozyplayer.prev_wielded_lights == 1
		then
			local p = cozyplayer.prev_wielded_lights[1]
			if p.x == pos.x and p.y == pos.y and p.z == pos.z and p.placed_cid == new_cid then
				return
			end
		end
		cozylights:wielded_light_cleanup(nil, cozyplayer, radius)
		local node = cozylights.get_node(pos)
		local cid = minetest.get_content_id(node.name)
		if cid == c_air or (cid >= c_light1 and cid <= c_lights[14]) then
			if new_cid ~= cid then
				cozyplayer.prev_wielded_lights[1] = {
					x = pos.x,
					y = pos.y,
					z = pos.z,
					old_cid = cid,
					old_p2 = node.param2,
					placed_cid = new_cid,
				}
				minetest.swap_node(pos, { name = new_name, param2 = node.param2 })
			end
		end
		cozyplayer.last_wield_radius = radius
		gent_total = gent_total + mf((os.clock() - t) * 1000)
		gent_count = gent_count + 1
		print("Av wield illum time " .. mf(gent_total / gent_count) .. " ms. Sample of: " .. gent_count)
		return
	end
	local update_needed = 0
	if vm == nil then
		vm = cozylights.get_voxel_manip()
		local read_min = vector.subtract(pos, radius + 1)
		local read_max = vector.add(pos, radius + 1)
		if cozyplayer.prev_wielded_lights then
			for i = 1, #cozyplayer.prev_wielded_lights do
				local p = cozyplayer.prev_wielded_lights[i]
				if p.x < read_min.x then
					read_min.x = p.x
				elseif p.x > read_max.x then
					read_max.x = p.x
				end
				if p.y < read_min.y then
					read_min.y = p.y
				elseif p.y > read_max.y then
					read_max.y = p.y
				end
				if p.z < read_min.z then
					read_min.z = p.z
				elseif p.z > read_max.z then
					read_max.z = p.z
				end
			end
		end
		emin, emax = vm:read_from_map(read_min, read_max)
		cozyplayer.data_buffer = cozyplayer.data_buffer or {}
		cozyplayer.param2_buffer = cozyplayer.param2_buffer or {}
		data = vm:get_data(cozyplayer.data_buffer)
		param2data = vm:get_param2_data(cozyplayer.param2_buffer)
		a = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
		update_needed = 1
	end
	destroy_stale_wielded_light(data, param2data, a, cozyplayer)
	local c_light14 = c_lights[14]
	local px, py, pz = pos.x, pos.y, pos.z
	local idx_below = a:index(px, py - 1, pz)
	local idx_above = a:index(px, py + 1, pz)
	local cidb = data[idx_below]
	local cida = data[idx_above]
	local c_light_debug14 = c_light14 + 14
	if cidb and cida then
		if
			(cidb == c_air or (cidb >= c_lights[1] and cidb <= c_light_debug14))
			and cida ~= c_air
			and (cida < c_lights[1] or cida > c_light_debug14)
		then
			py = py - 1
		end
	else
		return
	end
	local zstride, ystride = a.zstride, a.ystride
	local dirs = { -ystride, ystride, -1, 1, -zstride, zstride }
	local dedup = {}
	local base_idx = a:index(px, py, pz)
	for i = 1, #ray_cache do
		local ray = ray_cache[i]
		local len = #ray
		for r = 1, len, 4 do
			local dx = ray[r]
			local dy = ray[r + 1]
			local dz = ray[r + 2]
			local dim = ray[r + 3]
			local idx = base_idx + dz * zstride + dy * ystride + dx
			local cid = data[idx]
			if not cid or (cid ~= c_air and (cid < c_lights[1] or cid > c_light14)) then
				break
			end
			for n = 1, 6 do
				local adj_cid = data[idx + dirs[n]]
				if adj_cid and ((adj_cid < c_lights[1] and adj_cid ~= c_air) or adj_cid > c_light14) then
					local light = c_lights[dim]
					if cid == c_air or light > cid then
						if not dedup[idx] then
							dedup[idx] = true
							cozyplayer.prev_wielded_lights[#cozyplayer.prev_wielded_lights + 1] = {
								x = px + dx,
								y = py + dy,
								z = pz + dz,
								old_cid = data[idx],
								old_p2 = param2data[idx],
								placed_cid = light,
							}
						end
						data[idx] = light
					end
					break
				end
			end
		end
	end
	if update_needed == 1 then
		vm:set_data(data)
		vm:write_to_map(false)
	end
	cozyplayer.last_wield_radius = radius
	gent_total = gent_total + mf((os.clock() - t) * 1000)
	gent_count = gent_count + 1
	print("Av wield illum time " .. mf(gent_total / gent_count) .. " ms. Sample of: " .. gent_count)
end
