dofile("../helpers.lua")
dofile("../../../builtin/common/vector.lua")

-- this exists to basically find sweet spot for dirfloor in fastest way i could come up with to spread light.
-- dirfloor should change somehow cheaply according to radius maybe or 
-- according to ray angles, or, dirfloor should be split in x,y,z axis equivalents
-- and those should be adjusted.
-- some node misses start to appear from radius 6
local dirfloor = 0.51

local mf = math.floor

-- radius*radius = x*x + y*y + z*z
local function get_full_sphere(radius)
	local sphere = {}
	local count, offset, rad_pow2, stride_y = 0, 1+radius, radius * (radius + 1), radius+2
	local stride_z = stride_y * stride_y
	for z = -radius, radius do
		for y = -radius, radius do
			for x = -radius, radius do
				local pow2 = x * x + y * y + z * z
				if pow2 <= rad_pow2 then
					local i = (z + offset) * stride_z + (y + offset) * stride_y + x + offset + 1
					if sphere[i] ~= true then
						sphere[i] = true
						count = count + 1
					end
				end
			end
		end
	end
	return sphere, count
end

local function get_sphere_surface(radius)
	local sphere_surface = {}
	local rad_pow2_min, rad_pow2_max = radius * (radius - 1), radius * (radius + 1)
	for z = -radius, radius do
		for y = -radius, radius do
			for x = -radius, radius do
				local squared = x * x + y * y + z * z
				if squared >= rad_pow2_min and squared <= rad_pow2_max then
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
		if not ray[idx] then
			ray[idx] = true
		end
	end
	return ray
end

local function reconstruct_sphere(radius)
	local pos = {x=0,y=0,z=0}
	local sphere, sphere_len = get_full_sphere(radius)
	local sphere_surface = get_sphere_surface(radius)
	local reconstructed_sphere = {}
	local reconstructed_sphere_len = 0
	for _,pos2 in ipairs(sphere_surface) do
		local ray = raycast(vector.direction(pos, pos2),radius)
		for i,_ in pairs(ray) do
			if not reconstructed_sphere[i] then
				reconstructed_sphere[i] = true
				reconstructed_sphere_len = reconstructed_sphere_len + 1
			end
		end
	end
	
	print("#sphere: "..sphere_len)
	print("#reconstructed_sphere: "..reconstructed_sphere_len)
	--print(cozylights:dump(sphere))
	--print(cozylights:dump(reconstructed_sphere))
end

for i=1,1 do
	dirfloor = dirfloor - 0.01
	print("running with dirfloor: "..dirfloor)
	reconstruct_sphere(1)
end


