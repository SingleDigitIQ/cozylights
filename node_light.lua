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
local c_light_debug14 = c_lights[14] + 14
local hash_pos = cozylights.hash_pos
local gent_total = 0
local gent_count = 0

local remt_total = 0
local remt_count = 0
local mf = math.floor

function cozylights:draw_node_light(pos, cozy_item, cozy_name, vm, a, data, param2data, fix_edges)
	local hash = hash_pos(pos)
	if cozylights.drawn_nodes[hash] then
		return
	end
	local actual_node = minetest.get_node(pos)
	if not cozylights.cozy_items[actual_node.name] then
		return
	end
	cozylights.drawn_nodes[hash] = true
	local t = os.clock()
	local update_needed = 0
	local radius, dim_levels = cozylights:calc_dims(cozy_name, cozy_item)
	--print("cozy_item:"..cozylights:dump(cozy_item))
	--print("dim_levels: "..cozylights:dump(dim_levels))
	--print("spreading light over a sphere with radius of "..radius)
	if vm == nil then
		_, _, vm, data, param2data, a = cozylights:getVoxelManipData(pos, radius)
		update_needed = 1
	end
	local sphere_surface = cozylights:get_sphere_surface(radius)
	local draw_pos = pos
	fix_edges = fix_edges == nil and cozylights.always_fix_edges or fix_edges
	if fix_edges == true then
		local visited_pos = {}
		for i, pos2 in ipairs(sphere_surface) do
			local end_pos = { x = draw_pos.x + pos2.x, y = draw_pos.y + pos2.y, z = draw_pos.z + pos2.z }
			cozylights:lightcast_fix_edges(
				draw_pos,
				vector.direction(draw_pos, end_pos),
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
			local end_pos = { x = draw_pos.x + pos2.x, y = draw_pos.y + pos2.y, z = draw_pos.z + pos2.z }
			cozylights.dir = vector.direction(draw_pos, end_pos)
			cozylights:lightcast(draw_pos, vector.direction(draw_pos, end_pos), radius, data, param2data, a, dim_levels)
		end
	end
	if update_needed == 1 then
		cozylights:setVoxelManipData(vm, data, param2data, true)
	end
	gent_total = gent_total + mf((os.clock() - t) * 1000)
	gent_count = gent_count + 1
	print("Av illum time " .. mf(gent_total / gent_count) .. " ms. Sample of: " .. gent_count)
end

-- handle_async?
function cozylights:rebuild_light()
	local single_light_queue = self.single_light_queue
	if #single_light_queue == 0 then
		return
	end
	local s = single_light_queue[1]
	table.remove(single_light_queue, 1)
	if not s.cozy_item then
		return
	end
	self:draw_node_light(s.pos, s.cozy_item, s.cozy_item.name)
end

function cozylights:destroy_light(pos, cozy_item, cozy_name, tx_locks)
	local t = os.clock()
	local original_hash = hash_pos(pos)
	cozylights.drawn_nodes[original_hash] = nil
	cozylights.recently_updated[original_hash] = nil
	local radius = cozylights:calc_dims(cozy_name, cozy_item)
	local _, _, vm, data, param2data, a = cozylights:getVoxelManipData(pos, radius)
	local center_y = pos.y
	local base_idx = a:index(pos.x, center_y, pos.z)
	local ystride, zstride = a.ystride, a.zstride
	local sweep_rad = radius + 1
	local rad_sq = sweep_rad * sweep_rad
	for z = -sweep_rad, sweep_rad do
		local z_sq = z * z
		local idx_z = base_idx + z * zstride
		for y = -sweep_rad, sweep_rad do
			local yz_sq = z_sq + y * y
			if yz_sq <= rad_sq then
				local idx_zy = idx_z + y * ystride
				local max_x = math.floor(math.sqrt(rad_sq - yz_sq))
				for x = -max_x, max_x do
					local idx = idx_zy + x
					local n_cid = data[idx]
					if n_cid >= c_light1 and n_cid <= c_light_debug14 then
						data[idx] = c_air
						param2data[idx] = 0
					end
				end
			end
		end
	end
	cozylights:setVoxelManipData(vm, data, param2data)
	local posrebuilds = {}
	local global_rebuild_minp = { x = pos.x, y = pos.y, z = pos.z }
	local global_rebuild_maxp = { x = pos.x, y = pos.y, z = pos.z }
	for bound, nodenames in pairs(cozylights.rebuild_bounds) do
		local search_range = bound + radius
		local s_minp = vector.subtract(pos, search_range)
		local s_maxp = vector.add(pos, search_range)
		global_rebuild_minp = {
			x = math.min(global_rebuild_minp.x, s_minp.x),
			y = math.min(global_rebuild_minp.y, s_minp.y),
			z = math.min(global_rebuild_minp.z, s_minp.z),
		}
		global_rebuild_maxp = {
			x = math.max(global_rebuild_maxp.x, s_maxp.x),
			y = math.max(global_rebuild_maxp.y, s_maxp.y),
			z = math.max(global_rebuild_maxp.z, s_maxp.z),
		}
		local found = cozylights.find_nodes_in_area(s_minp, s_maxp, nodenames)
		for i = 1, #found do
			local f_pos = found[i]
			if tx_locks then
				local f_hash = hash_pos(f_pos)
				if not tx_locks[f_hash] then
					tx_locks[f_hash] = true
					posrebuilds[#posrebuilds + 1] = f_pos
				end
			else
				posrebuilds[#posrebuilds + 1] = f_pos
			end
		end
	end
	local rebuild_minp, rebuild_maxp = global_rebuild_minp, global_rebuild_maxp
	local pos_hash = original_hash
	local sources = {}
	local single_light_queue = cozylights.single_light_queue
	if #posrebuilds > 0 then
		for i = 1, #posrebuilds do
			local posrebuild = posrebuilds[i]
			local posrebuild_hash = hash_pos(posrebuild)
			if posrebuild_hash ~= pos_hash then
				local node = cozylights.get_node(posrebuild)
				local rebuild_radius, _ = cozylights:calc_dims(node.name, cozylights.cozy_items[node.name])
				local max_distance = rebuild_radius + radius
				if max_distance > vector.distance(pos, posrebuild) then
					cozylights.drawn_nodes[posrebuild_hash] = nil
					cozylights.recently_updated[posrebuild_hash] = nil
					if
						vector.in_area(vector.subtract(posrebuild, rebuild_radius), rebuild_minp, rebuild_maxp)
						and vector.in_area(vector.add(posrebuild, rebuild_radius), rebuild_minp, rebuild_maxp)
					then
						sources[#sources + 1] = {
							pos = posrebuild,
							cozy_item = cozylights.cozy_items[node.name],
						}
					else
						single_light_queue[#single_light_queue + 1] = {
							pos = posrebuild,
							cozy_item = cozylights.cozy_items[node.name],
						}
					end
				end
			end
		end
	end
	if #sources > 0 then
		cozylights:push_area_queue(rebuild_minp, rebuild_maxp, sources)
	end
	remt_total = remt_total + mf((os.clock() - t) * 1000)
	remt_count = remt_count + 1
	print("Av light removal time " .. mf(remt_total / remt_count) .. " ms. Sample of: " .. remt_count)
end

function cozylights:update_cone(pos_broken)
	local t = os.clock()
	local max_bound = 15
	for bound, _ in pairs(cozylights.rebuild_bounds) do
		if bound > max_bound then
			max_bound = bound
		end
	end
	local s_minp = vector.subtract(pos_broken, max_bound)
	local s_maxp = vector.add(pos_broken, max_bound)
	local nearby_lights = cozylights.storage.get_lights_in_area(s_minp, s_maxp)
	local posrebuilds = {}
	for i = 1, #nearby_lights do
		local l_data = nearby_lights[i]
		if l_data.generated then
			local V_a = vector.subtract(pos_broken, l_data.pos)
			local D_sq = V_a.x * V_a.x + V_a.y * V_a.y + V_a.z * V_a.z
			if D_sq <= l_data.radius * l_data.radius and D_sq > 0 then
				posrebuilds[#posrebuilds + 1] = {
					pos = l_data.pos,
					radius = l_data.radius,
				}
			end
		end
	end
	if #posrebuilds == 0 then
		return
	end
	local min_read = { x = pos_broken.x, y = pos_broken.y, z = pos_broken.z }
	local max_read = { x = pos_broken.x, y = pos_broken.y, z = pos_broken.z }
	local active_casts = {}
	local VOXEL_SQ_RADIUS = (math.sqrt(3) / 2) ^ 2 * 1.5
	for i = 1, #posrebuilds do
		local source_pos = posrebuilds[i].pos
		local radius = posrebuilds[i].radius
		local actual_node = cozylights.get_node(source_pos)
		local cozy_item = cozylights.cozy_items[actual_node.name]
		if cozy_item then
			local _, base_dim_levels = cozylights:calc_dims(actual_node.name, cozy_item)
			local dim_levels = base_dim_levels
			if radius > #base_dim_levels then
				dim_levels = {}
				for k = 1, radius do
					dim_levels[k] = base_dim_levels[k] or 1
				end
			end
			local node_below = minetest.get_node({ x = source_pos.x, y = source_pos.y - 1, z = source_pos.z }).name
			local node_above = minetest.get_node({ x = source_pos.x, y = source_pos.y + 1, z = source_pos.z }).name
			local ylvl = 1
			if node_below == "air" and node_above ~= "air" then
				ylvl = -1
			end
			local adj_source = { x = source_pos.x, y = source_pos.y + ylvl, z = source_pos.z }
			local V_a = vector.subtract(pos_broken, adj_source)
			local D_sq = V_a.x * V_a.x + V_a.y * V_a.y + V_a.z * V_a.z
			local D = math.sqrt(D_sq)
			local ux, uy, uz = V_a.x / D, V_a.y / D, V_a.z / D
			local cos_theta = 1.0 - (VOXEL_SQ_RADIUS / (2 * D_sq))
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
				dim_levels = dim_levels,
				targets = valid_targets,
			}
		end
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
				cozylights:lightcast_fix_edges(
					cast.adj_source,
					dir,
					cast.radius,
					data,
					param2data,
					a,
					cast.dim_levels,
					visited_pos
				)
			else
				cozylights:lightcast(cast.adj_source, dir, cast.radius, data, param2data, a, cast.dim_levels)
			end
		end
	end
	cozylights:setVoxelManipData(vm, data, param2data, true)
	print("Cone update time: " .. math.floor((os.clock() - t) * 1000) .. " ms")
end
