local storage = minetest.get_mod_storage()
local schar = string.char
local sbyte = string.byte
local floor = math.floor
cozylights.storage = {}
local active_chunks = {}
local dirty_queue = {}
local dirty_count = 0
local FLUSH_RATE = 2

local function serialize_chunk(light_map)
	local buffer = {}
	local n = 1
	for local_idx, data in pairs(light_map) do
		local b1 = local_idx % 256
		local b2 = floor(local_idx / 256)
		if data.generated then
			b2 = b2 + 128
		end
		local b3 = data.radius

		buffer[n] = schar(b1, b2, b3)
		n = n + 1
	end
	-- table.concat is apparently the fastest way to build strings in luajit
	return table.concat(buffer)
end

local function deserialize_chunk(payload)
	local light_map = {}
	if not payload or payload == "" then
		return light_map
	end

	local len = #payload
	for i = 1, len, 3 do
		local b1, b2, b3 = sbyte(payload, i, i + 2)
		local generated = b2 >= 128
		local upper_idx = generated and (b2 - 128) or b2
		local local_idx = upper_idx * 256 + b1

		light_map[local_idx] = {
			radius = b3,
			generated = generated,
		}
	end
	return light_map
end

local function get_chunk(hash)
	if not active_chunks[hash] then
		local payload = storage:get_string(tostring(hash))
		active_chunks[hash] = deserialize_chunk(payload)
	end
	return active_chunks[hash]
end

local function mark_dirty(hash)
	if not dirty_queue[hash] then
		dirty_queue[hash] = true
		dirty_count = dirty_count + 1
	end
end

function cozylights.storage.pos_to_internal(pos)
	local block_x = floor(pos.x / 16)
	local block_y = floor(pos.y / 16)
	local block_z = floor(pos.z / 16)
	local hash = minetest.hash_node_position({ x = block_x, y = block_y, z = block_z })
	local loc_x = pos.x - (block_x * 16)
	local loc_y = pos.y - (block_y * 16)
	local loc_z = pos.z - (block_z * 16)
	local local_idx = loc_x + (loc_y * 16) + (loc_z * 256)
	return hash, local_idx
end

function cozylights.storage.set_light(pos, radius, is_generated)
	local hash, local_idx = cozylights.storage.pos_to_internal(pos)
	local chunk = get_chunk(hash)
	chunk[local_idx] = {
		radius = radius,
		generated = is_generated,
	}
	mark_dirty(hash)
end

function cozylights.storage.get_light(pos)
	local hash, local_idx = cozylights.storage.pos_to_internal(pos)
	local chunk = get_chunk(hash)
	return chunk[local_idx]
end

function cozylights.storage.remove_light(pos)
	local hash, local_idx = cozylights.storage.pos_to_internal(pos)
	local chunk = get_chunk(hash)
	if chunk[local_idx] then
		chunk[local_idx] = nil
		mark_dirty(hash)
	end
end

function cozylights.storage.get_lights_in_area(minp, maxp)
	local results = {}
	local count = 1
	local floor = math.floor
	local min_bx = floor(minp.x / 16)
	local max_bx = floor(maxp.x / 16)
	local min_by = floor(minp.y / 16)
	local max_by = floor(maxp.y / 16)
	local min_bz = floor(minp.z / 16)
	local max_bz = floor(maxp.z / 16)
	local minx, miny, minz = minp.x, minp.y, minp.z
	local maxx, maxy, maxz = maxp.x, maxp.y, maxp.z
	for bz = min_bz, max_bz do
		local z_hash = (bz + 32768) * 4294967296
		local base_z = bz * 16
		for by = min_by, max_by do
			local y_hash = z_hash + (by + 32768) * 65536
			local base_y = by * 16
			for bx = min_bx, max_bx do
				local hash = y_hash + (bx + 32768)
				local chunk = active_chunks[hash]
				if not chunk then
					local payload = storage:get_string(tostring(hash))
					chunk = deserialize_chunk(payload)
					active_chunks[hash] = chunk
				end
				local base_x = bx * 16
				for local_idx = 0, 4095 do
					local data = chunk[local_idx]
					if data then
						local loc_x = local_idx % 16
						local loc_y = floor(local_idx / 16) % 16
						local loc_z = floor(local_idx / 256)
						local world_x = base_x + loc_x
						local world_y = base_y + loc_y
						local world_z = base_z + loc_z
						if
							world_x >= minx
							and world_x <= maxx
							and world_y >= miny
							and world_y <= maxy
							and world_z >= minz
							and world_z <= maxz
						then
							results[count] = {
								pos = { x = world_x, y = world_y, z = world_z },
								radius = data.radius,
								generated = data.generated,
							}
							count = count + 1
						end
					end
				end
			end
		end
	end
	return results
end

local flush_timer = 0
minetest.register_globalstep(function(dtime)
	if dirty_count == 0 then
		return
	end
	flush_timer = flush_timer + dtime
	if flush_timer > 0.5 then
		flush_timer = 0
		local flushed = 0
		for hash, _ in pairs(dirty_queue) do
			local chunk = active_chunks[hash]
			local payload = serialize_chunk(chunk)
			if payload == "" then
				storage:set_string(tostring(hash), "")
			else
				storage:set_string(tostring(hash), payload)
			end
			dirty_queue[hash] = nil
			dirty_count = dirty_count - 1
			flushed = flushed + 1
			if flushed >= FLUSH_RATE then
				break
			end
		end
	end
end)

minetest.register_on_shutdown(function()
	for hash, _ in pairs(dirty_queue) do
		local chunk = active_chunks[hash]
		local payload = serialize_chunk(chunk)
		storage:set_string(tostring(hash), payload)
	end
end)
