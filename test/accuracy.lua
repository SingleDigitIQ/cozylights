dofile("../helpers.lua")
dofile("../../../builtin/common/vector.lua")

-- this exists to basically find sweet spot for dirfloor in fastest known to me way to spread light.
-- dirfloor should change somehow cheaply according to radius maybe or most likely
-- according to ray angles
-- some node misses start to appear from radius 6
local dirfloor = 0.51

local mf = math.floor
-- adapted from worledit (Uberi, Sfan5, khonkhortisan, ShadowNinja, Sebastian Ponce, HybridDog)
local function get_full_sphere(radius)
	local sphere = {}
	local max_radius = radius * (radius + 1)
	local offset_x, offset_y, offset_z = 1+radius, 1+radius, 1+radius
	local stride_z, stride_y = (radius+2)*radius+2, radius+2
	for z = -radius, radius do
		local new_z = (z + offset_z) * stride_z + 1
		for y = -radius, radius do
			local new_y = new_z + (y + offset_y) * stride_y
			for x = -radius, radius do
				local squared = x * x + y * y + z * z
				if squared <= max_radius then
					local i = new_y + (x + offset_x)
					if findIn(i,sphere) == false then
						sphere[i] = true
					end
				end
			end
		end
	end
	return sphere
end

--somewhat adapted from worldedit code
local function get_sphere_surface(radius)
	local sphere_surface = {}
	local min_radius, max_radius = radius * (radius - 1), radius * (radius + 1)
	for z = -radius, radius do
		for y = -radius, radius do
			for x = -radius, radius do
				local squared = x * x + y * y + z * z
				if squared >= min_radius and squared <= max_radius then
					sphere_surface[#sphere_surface+1] = {x=x,y=y,z=z}
				end
			end
		end
	end
	return sphere_surface
end

local function raycast(dir, radius)
	local ray = {}
	local stride_z, stride_y = (radius+2)*radius+2, radius+2
	local dx, dy, dz = dir.x, dir.y, dir.z
	for i = 1, radius do
		local x = mf(dx*i+dirfloor)
		local y = mf(dy*i+dirfloor)
		local z = mf(dz*i+dirfloor)
		local idx = (z+1+radius)*stride_z+1+(y+1+radius)*stride_y+(x+1+radius)
		if ray[idx] ~= true then
			ray[idx] = true
		end
	end
	return ray
end

local function reconstruct_sphere(radius)
	local pos = {x=0,y=0,z=0}
	local sphere = get_full_sphere(radius)
	local sphere_surface = get_sphere_surface(radius)
	local reconstructed_sphere = {}
	for _,pos2 in ipairs(sphere_surface) do
		local ray = raycast(vector.direction(pos, pos2),radius)
		for i,_ in pairs(ray) do
			if reconstructed_sphere[i] ~= true then
				reconstructed_sphere[i] = true
			end
		end
	end
	local count = 0
	for _,val in pairs(sphere) do
		if val == true then count = count + 1 end
	end
	print("#sphere: "..count)

	count = 0
	for _,val in pairs(reconstructed_sphere) do
		if val == true then count = count + 1 end
	end

	print("#reconstructed_sphere: "..count)
	--print(dump(sphere))
	--print(dump(reconstructed_sphere))
end

for i=1,1 do
	dirfloor = dirfloor - 0.01
	print("running with dirfloor: "..dirfloor)
	reconstruct_sphere(5)
end


