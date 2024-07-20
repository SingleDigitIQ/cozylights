local c_air = minetest.get_content_id("air")
local c_light1 = minetest.get_content_id("cozylights:light1")

local c_lights = { c_light1, c_light1 + 1, c_light1 + 2, c_light1 + 3, c_light1 + 4, c_light1 + 5, c_light1 + 6,
	c_light1 + 7, c_light1 + 8, c_light1 + 9, c_light1 + 10, c_light1 + 11, c_light1 + 12, c_light1 + 13 }

local gent_total = 0
local gent_count = 0

local remt_total = 0
local remt_count = 0
local mf = math.floor

local dirfloor = 0.5
--- raycast but normal
local function darknesscast(pos, dir, radius,data,param2data, a)
	local px, py, pz, dx, dy, dz = pos.x, pos.y, pos.z, dir.x, dir.y, dir.z
	local c_light1 = c_lights[1]
	local c_light14 = c_lights[14]
	for i = 1, radius do
		local x = mf(dx*i+dirfloor) + px
		local y = mf(dy*i+dirfloor) + py
		local z = mf(dz*i+dirfloor) + pz
		local idx = a:index(x,y,z)
		local cid = data[idx]
		if cid and (cid == c_air or (cid >= c_light1 and cid <= c_light14+14)) then
			data[idx] = c_air
			param2data[idx] = 0
		else
			break
		end
	end
end

function cozylights:draw_node_light(pos,cozy_item,vm,a,data,param2data)
	local t = os.clock()
	local update_needed = 0
	local radius, dim_levels = cozylights:calc_dims(cozy_item)
	
	print("dim_levels: "..cozylights:dump(dim_levels))
	print("spreading light over a sphere with radius of "..radius)
	if vm == nil then
		_,_,vm,data,param2data,a = cozylights:getVoxelManipData(pos,radius)
		update_needed = 1
	end
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
	if cozylights.always_fix_edges == true then
		local visited_pos = {}
		for i,pos2 in ipairs(sphere_surface) do
			local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
			cozylights:lightcast_fix_edges(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels,visited_pos)
		end
	else
		for i,pos2 in ipairs(sphere_surface) do
			local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
			cozylights.dir = vector.direction(pos, end_pos)
			cozylights:lightcast(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels)
		end
	end
	if update_needed == 1 then
		cozylights:setVoxelManipData(vm,data,param2data,true)
	end
	gent_total = gent_total + mf((os.clock() - t) * 1000)
	gent_count = gent_count + 1
	print("Average illum time " .. mf(gent_total/gent_count) .. " ms. Sample of: "..gent_count)
end

function cozylights:destroy_light(pos, cozy_item)
	local t = os.clock()
	local radius = cozylights:calc_dims(cozy_item)
	local _,_,vm,data,param2data,a = cozylights:getVoxelManipData(pos, radius)
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
	for i,pos2 in ipairs(sphere_surface) do
		local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
		darknesscast(pos, vector.direction(pos, end_pos),radius,data,param2data, a)
	end

	--[[local posrebuilds = minetest.find_nodes_in_area(vector.subtract(pos, 40), vector.add(pos, 40), cozylights.cozy_nodes)
	local pos_hash = pos.x + (pos.y-ylvl)*100 + pos.z*10000
	for i=1,#posrebuilds do
		local posrebuild_hash = posrebuilds[i].x + (posrebuilds[i].y)*100 + posrebuilds[i].z*10000
		if posrebuild_hash ~= pos_hash then
			local node = minetest.get_node(posrebuilds[i])
			local max_distance = cozylights.cozy_items[node.name].light_source*cozylights.reach_factor + radius
			if max_distance > vector.distance(pos,posrebuilds[i]) then
				-- handle_async?
				cozylights:draw_node_light(posrebuilds[i], cozylights.cozy_items[node.name])
				--cozylights:rebuild_light(posrebuilds[i], cozylights.cozy_items[node.name],vm,a,data,param2data)
			end
		end
	end]]

	cozylights:setVoxelManipData(vm,data,param2data)
	
	remt_total = remt_total + mf((os.clock() - t) * 1000)
	remt_count = remt_count + 1
	print("Average light removal time " .. mf(remt_total/remt_count) .. " ms. Sample of: "..remt_count)
end

function cozylights:rebuild_light(pos, cozy_item,vm,a,data,param2data)
	local radius, dim_levels = cozylights:calc_dims(cozy_item)
	print("rebuilding light for position "..cozylights:dump(pos))
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
	for _,pos2 in ipairs(sphere_surface) do
		local end_pos = {x=pos.x+pos2.x,y=pos.y+pos2.y,z=pos.z+pos2.z}
		if a:containsp(end_pos) then
			cozylights:lightcast(pos, vector.direction(pos, end_pos),radius,data,param2data,a,dim_levels)
		end
	end
end