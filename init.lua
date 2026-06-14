cozylights = {
	-- constant size values and tables
	version = "0.3.2",
	default_size = tonumber(minetest.settings:get("mapfix_default_size")) or 40,
	global_brightness = tonumber(minetest.settings:get("cozylights_global_brightness")) or 12,
	global_radius = tonumber(minetest.settings:get("cozylights_global_radius")) or 15,
	global_strength = tonumber(minetest.settings:get("cozylights_global_strength")) or 0.5,
	brightness_factor = tonumber(minetest.settings:get("cozylights_brightness_factor")) or 8,
	wield_step = tonumber(minetest.settings:get("cozylights_wield_step")) or 0.1,
	brush_hold_step = tonumber(minetest.settings:get("cozylights_brush_hold_step")) or 0.07,
	on_gen_step = tonumber(minetest.settings:get("cozylights_on_gen_step")) or 0.7,
	max_wield_light_radius = tonumber(minetest.settings:get("cozylights_wielded_light_radius")) or 10,
	override_engine_lights = minetest.settings:get_bool("cozylights_override_engine_lights", false),
	always_fix_edges = minetest.settings:get_bool("cozylights_always_fix_edges", false),
	uncozy_mode = tonumber(minetest.settings:get("cozylights_uncozy_mode")) or 0,
	crispy_potato = minetest.settings:get_bool("cozylights_crispy_potato", true),
	-- appears nodes and items might not necessarily be the same array
	source_nodes = nil,
	cozy_items = nil,
	cozycids_sunlight_propagates = {},
	cozycids_light_sources = {},
	cozyplayers = {},
	area_queue = {},
	single_light_queue = {},
	modpath = minetest.get_modpath(minetest.get_current_modname()),
	is_mcl = false,
	mcl_player_context = false, -- a hack around voxelibre hack that hacks around engine api
}

local modpath = minetest.get_modpath(minetest.get_current_modname())
dofile(modpath .. "/helpers.lua")

if cozylights:mod_loaded("br_core") then
	cozylights.brightness_factor = cozylights.brightness_factor - 6
end

if cozylights:mod_loaded("mcl_core") then
	cozylights.is_mcl = true
end

dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/shared.lua")
dofile(modpath .. "/chat_commands.lua")
dofile(modpath .. "/wield_light.lua")
dofile(modpath .. "/node_light.lua")
dofile(modpath .. "/light_brush.lua")
dofile(modpath .. "/api_overrides.lua")
dofile(modpath .. "/manual.lua")
dofile(modpath .. "/storage.lua")

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
local mf = math.floor

------------------------------------------
minetest.register_on_mods_loaded(function()
	local source_nodes = {}
	local cozy_items = {}
	local cozycids_sunlight_propagates = {}
	local cozycids_light_sources = {}
	local override = cozylights.override_engine_lights
	local function is_transient_light(def)
		if string.find(def.name, "everness:") ~= nil and def.groups and def.groups.vine ~= nil then
			return true
		end
		-- these are some forest fires and other
		if def.buildable_to == true or def.drawtype == "plantlike" then
			local name = def.name
			if string.find(name, "flame", 1, true) then
				return true
			end
			if string.find(name, "fire", 1, true) and not string.find(name, "firefly", 1, true) then
				return true
			end
		end
		return false
	end
	for _, def in pairs(minetest.registered_items) do
		if cozylights.is_mcl then
			local orig_on_place = def.on_place or minetest.item_place
			minetest.override_item(def.name, {
				on_place = function(itemstack, placer, pointed_thing)
					cozylights.mcl_player_context = true
					local result = { orig_on_place(itemstack, placer, pointed_thing) }
					cozylights.mcl_player_context = false
					return unpack(result)
				end,
			})
		end
		if
			def.light_source
			and def.light_source > 1
			and def.drawtype ~= "airlike"
			and def.drawtype ~= "liquid"
			and string.find(def.name, "lava_flowing") == nil
			and string.find(def.name, "lava_source") == nil
		then
			if not is_transient_light(def) then
				cozy_items[def.name] = {
					name = def.name,
					light_source = def.light_source or 0,
					floodable = def.floodable or false,
					modifiers = nil,
				}
				if not string.find(def.name, "cozylights:light") then
					source_nodes[#source_nodes + 1] = def.name
				end
			end
		end
	end
	for node, def in pairs(minetest.registered_nodes) do
		if def.sunlight_propagates == true then
			local cid = minetest.get_content_id(def.name)
			cozycids_sunlight_propagates[cid] = true
		end
		if
			def.light_source
			and def.light_source > 1
			and def.drawtype ~= "airlike"
			and def.drawtype ~= "liquid"
			and not string.find(def.name, "lava_flowing")
			and not string.find(def.name, "lava_source")
			--and def.liquid_viscosity == nil and def.liquid_renewable == nil and def.drowning == nil
		then
			local cid = minetest.get_content_id(def.name)
			if cid < c_lights[1] or cid > c_lights[14] + 14 then
				if not is_transient_light(def) then
					cozycids_light_sources[cid] = true
					local base_on_destruct = def.on_destruct
					minetest.override_item(node, {
						on_destruct = function(pos)
							if base_on_destruct then
								base_on_destruct(pos)
							end
							cozylights.storage.remove_light(pos)
							local cozy_item = cozy_items[def.name]
							print(cozylights:dump(pos))
							print(def.name .. " is destroyed")
							if cozy_item then
								cozylights:destroy_light(pos, cozy_item, def.name)
							end
						end,
					})
					local base_on_construct = def.on_construct
					local light = override == true and 1 or def.light_source
					if def.name == "br_core:ceiling_light_1" then
						light = def.light_source - 7
					end
					minetest.override_item(node, {
						light_source = light,
						use_texture_alpha = def.use_texture_alpha or "clip",
						on_construct = function(pos)
							if base_on_construct then
								base_on_construct(pos)
							end
							local cozy_item = cozy_items[def.name]
							if cozy_item then
								local radius, _ = cozylights:calc_dims(def.name, cozy_item)
								cozylights.storage.set_light(pos, radius, true)
								cozylights:draw_node_light(pos, cozy_item, def.name)
							end
						end,
					})
				end
			end
		end
		-- this is a bit excessive
		if cozylights.is_mcl then
			if def.sunlight_propagates ~= true and def.drawtype ~= "liquid" and def.drawtype ~= "airlike" then
				local cid = minetest.get_content_id(def.name)
				if (cid < c_lights[1] or cid > c_lights[14] + 14) and not is_transient_light(def) then
					local base_on_construct = def.on_construct
					minetest.override_item(node, {
						on_construct = function(pos)
							if base_on_construct then
								base_on_construct(pos)
							end
							if cozylights.mcl_player_context then
								cozylights:update_shadow_cone(pos)
							end
						end,
					})
				end
			end
		end
	end
	cozylights.source_nodes = source_nodes
	cozylights.cozy_items = cozy_items
	cozylights.cozycids_sunlight_propagates = cozycids_sunlight_propagates
	cozylights.cozycids_light_sources = cozycids_light_sources
	--hoes in particular
	for name, def in pairs(minetest.registered_items) do
		local is_hoe = false
		if def.groups and def.groups.hoe then
			is_hoe = true
		elseif string.find(name, "hoe") then
			is_hoe = true
		end
		if is_hoe then
			if def.on_use then
				local orig_on_use = def.on_use
				minetest.override_item(name, {
					on_use = function(itemstack, user, pointed_thing)
						if pointed_thing and pointed_thing.type == "node" then
							local p_above =
								{ x = pointed_thing.under.x, y = pointed_thing.under.y + 1, z = pointed_thing.under.z }
							local above_node = cozylights.get_node(p_above)
							if above_node and string.find(above_node.name, "cozylights:light", 1, true) then
								minetest.remove_node(p_above)
								cozylights:push_area_queue(p_above, p_above, nil)
							end
						end
						return orig_on_use(itemstack, user, pointed_thing)
					end,
				})
			end
			if def.on_place then
				local orig_on_place = def.on_place
				minetest.override_item(name, {
					on_place = function(itemstack, placer, pointed_thing)
						if pointed_thing and pointed_thing.type == "node" then
							local p_above =
								{ x = pointed_thing.under.x, y = pointed_thing.under.y + 1, z = pointed_thing.under.z }
							local above_node = cozylights.get_node(p_above)
							if above_node and string.find(above_node.name, "cozylights:light", 1, true) then
								minetest.remove_node(p_above)
								cozylights:push_area_queue(p_above, p_above, nil)
							end
						end
						return orig_on_place(itemstack, placer, pointed_thing)
					end,
				})
			end
		end
	end
	-- more or less fast light rebuild
	cozylights.rebuild_bounds = {}
	for name, item in pairs(cozylights.cozy_items) do
		local r, _ = cozylights:calc_dims(name, item)
		local bound = math.max(15, math.floor(r / 15 + 0.5) * 15)
		if not cozylights.rebuild_bounds[bound] then
			cozylights.rebuild_bounds[bound] = {}
		end
		table.insert(cozylights.rebuild_bounds[bound], name)
	end
end)

--clean up possible stale wielded light on join, since on server shutdown we cant execute on_leave
--todo: make it more normal and less of a hack
function cozylights:on_join_cleanup(pos, radius)
	local vm = cozylights.get_voxel_manip()
	local emin, emax = vm:read_from_map(vector.subtract(pos, radius + 1), vector.add(pos, radius + 1))
	local data = vm:get_data()
	local a = VoxelArea:new({
		MinEdge = emin,
		MaxEdge = emax,
	})
	local param2data = vm:get_param2_data()
	local max_radius = radius * (radius + 1)
	for z = -radius, radius do
		for y = -radius, radius do
			for x = -radius, radius do
				--local p = vector.add(pos,{x=x,y=y,z=z})
				local p = { x = x + pos.x, y = y + pos.y, z = z + pos.z }
				local idx = a:indexp(p)
				local squared = x * x + y * y + z * z
				if
					data[idx] >= c_lights[1]
					and data[idx] <= c_light_debug14
					and param2data[idx] == 0
					and squared <= max_radius
				then
					data[idx] = c_air
				end
			end
		end
	end
	vm:set_data(data)
	vm:update_liquids()
	vm:write_to_map()
end

local hash_pos = cozylights.hash_pos

minetest.register_on_joinplayer(function(player)
	if not player then
		return
	end
	local pos = vector.round(player:get_pos())
	pos.y = pos.y + 1
	cozylights:on_join_cleanup(pos, 30)
	local meta = player:get_meta()
	if meta:get_int("cozylights_manual_issued") == 0 then
		local inv = player:get_inventory()
		if inv:room_for_item("main", "cozylights:alpha_manual") then
			inv:add_item("main", "cozylights:alpha_manual")
			meta:set_int("cozylights_manual_issued", 1)
		else
			minetest.log(
				"warning",
				"[cozylights] Failed to issue alpha manual to " .. player:get_player_name() .. " - Inventory saturated."
			)
		end
	end
	cozylights.cozyplayers[player:get_player_name()] = {
		name = player:get_player_name(),
		pos_hash = hash_pos(pos),
		wielded_item = 0,
		last_pos = pos,
		last_wield = "",
		prev_wielded_lights = {},
		lbrush = {
			brightness = 14,
			radius = 80,
			strength = 0.5,
			mode = 1,
			cover_only_surfaces = 0,
			pos_hash = 0,
		},
	}
end)
minetest.register_on_leaveplayer(function(player)
	if not player then
		return
	end
	local name = player:get_player_name()
	for i = 1, #cozylights.cozyplayers do
		if cozylights.cozyplayers[i].name == name then
			cozylights:wielded_light_cleanup(player, cozylights.cozyplayers[i], 30)
			table.remove(cozylights.cozyplayers, i)
		end
	end
end)

minetest.register_on_shutdown(function()
	for i = 1, #cozylights.cozyplayers do
		local player = minetest.get_player_by_name(cozylights.cozyplayers[i].name)
		if player ~= nil then
			cozylights:wielded_light_cleanup(player, cozylights.cozyplayers[i], 30)
		end
	end
end)

local agent_total = 0
local agent_count = 0
cozylights.recently_updated = {}

local MAX_QUEUE_VOLUME = 32768

function cozylights:push_area_queue(minp, maxp, sources)
	local queue = self.area_queue
	for i = 1, #queue do
		local q = queue[i]
		if
			minp.x >= q.minp.x
			and maxp.x <= q.maxp.x
			and minp.y >= q.minp.y
			and maxp.y <= q.maxp.y
			and minp.z >= q.minp.z
			and maxp.z <= q.maxp.z
		then
			if sources then
				q.sources = q.sources or {}
				for s = 1, #sources do
					q.sources[#q.sources + 1] = sources[s]
				end
			end
			return false
		end
		local merged_min = {
			x = math.min(minp.x, q.minp.x),
			y = math.min(minp.y, q.minp.y),
			z = math.min(minp.z, q.minp.z),
		}
		local merged_max = {
			x = math.max(maxp.x, q.maxp.x),
			y = math.max(maxp.y, q.maxp.y),
			z = math.max(maxp.z, q.maxp.z),
		}
		local merged_vol = (merged_max.x - merged_min.x + 1)
			* (merged_max.y - merged_min.y + 1)
			* (merged_max.z - merged_min.z + 1)
		if merged_vol <= MAX_QUEUE_VOLUME then
			q.minp = merged_min
			q.maxp = merged_max
			if sources then
				q.sources = q.sources or {}
				for s = 1, #sources do
					q.sources[#q.sources + 1] = sources[s]
				end
			end
			return true
		end
	end
	local new_job = { minp = minp, maxp = maxp, sources = sources }
	queue[#queue + 1] = new_job
	return true
end

local function build_lights_after_generated(minp, maxp, sources)
	local t = os.clock()
	local vm = cozylights.get_voxel_manip()
	local emin, emax = vm:read_from_map(vector.subtract(minp, 1), vector.add(maxp, 1))
	local data = vm:get_data()
	local param2data = vm:get_param2_data()
	local a = VoxelArea:new({
		MinEdge = emin,
		MaxEdge = emax,
	})
	local recently_updated = cozylights.recently_updated
	if sources then
		for i = 1, #sources do
			local s = sources[i]
			local hash = hash_pos(s.pos)
			if not recently_updated[hash] then
				recently_updated[hash] = true
				cozylights:draw_node_light(s.pos, s.cozy_item, s.cozy_item.name, vm, a, data, param2data)
			end
		end
	else
		local cozycids_light_sources = cozylights.cozycids_light_sources
		for i in a:iterp(minp, maxp) do
			local cid = data[i]
			if cozycids_light_sources[cid] then
				local p = a:position(i)
				local hash = hash_pos(p)
				if not recently_updated[hash] then
					recently_updated[hash] = true
					local name = minetest.get_name_from_content_id(cid)
					local cozy_item = cozylights.cozy_items[name]
					local radius, _ = cozylights:calc_dims(name, cozy_item)
					if a:containsp(vector.subtract(p, radius)) and a:containsp(vector.add(p, radius)) then
						cozylights:draw_node_light(p, cozy_item, cozy_item.name, vm, a, data, param2data)
					else
						table.insert(cozylights.single_light_queue, { pos = p, cozy_item = cozy_item })
					end
				end
			end
		end
	end
	cozylights:setVoxelManipData(vm, data, param2data, true)
	agent_total = agent_total + mf((os.clock() - t) * 1000)
	agent_count = agent_count + 1
	print(
		"Av build after generated time: "
			.. mf(agent_total / agent_count)
			.. " ms. Sample of: "
			.. agent_count
			.. ". Areas left: "
			.. #cozylights.area_queue
	)
end

local wield_light_enabled = cozylights.max_wield_light_radius > -1 and true or false
local wield_step = cozylights.wield_step
local brush_hold_step = cozylights.brush_hold_step
local on_gen_step = cozylights.on_gen_step

function cozylights:switch_wielded_light(enabled)
	wield_light_enabled = enabled
end

function cozylights:set_wield_step(_time)
	wield_step = _time
	minetest.settings:set("cozylights_wield_step", _time)
	cozylights.wield_step = _time
end

function cozylights:set_brush_hold_step(_time)
	brush_hold_step = _time
	minetest.settings:set("cozylights_brush_hold_step", _time)
	cozylights.brush_hold_step = _time
end

function cozylights:set_on_gen_step(_time)
	on_gen_step = _time
	minetest.settings:set("cozylights_on_gen_step", _time)
	cozylights.on_gen_step = _time
end

local brush_hold_dtime = 0
local wield_dtime = 0
local on_gen_dtime = 0

local total_brush_hold_time = 0
local total_brush_hold_step_count = 0
local total_wield_time = 0
local total_wield_step_count = 0
local uncozy_queue = {}

local function on_brush_hold(player, cozyplayer, pos, t)
	local control_bits = player:get_player_control_bits()
	if control_bits < 128 or control_bits >= 256 then
		return
	end
	local lb = cozyplayer.lbrush
	if lb.radius > 10 then
		return
	end
	local look_dir = player:get_look_dir()
	local endpos = vector.add(pos, vector.multiply(look_dir, 100))
	local hit = minetest.raycast(pos, endpos, false, false):next()
	if not hit then
		return
	end
	local nodenameunder = cozylights.get_node(hit.under).name
	local nodedefunder = minetest.registered_nodes[nodenameunder]
	local above = hit.above
	if nodedefunder.buildable_to == true then
		above.y = above.y - 1
	end
	local above_hash = hash_pos(above)
	if above_hash ~= lb.pos_hash or lb.mode == 2 or lb.mode == 4 or lb.mode == 5 then
		lb.pos_hash = above_hash
		cozylights:draw_brush_light(above, lb)
		local exe_time = os.clock() - t
		total_brush_hold_time = total_brush_hold_time + mf(exe_time * 1000)
		total_brush_hold_step_count = total_brush_hold_step_count + 1
		print(
			"Av cozy lights brush step time "
				.. mf(total_brush_hold_time / total_brush_hold_step_count)
				.. " ms. Sample of: "
				.. total_brush_hold_step_count
		)
		--if exe_time > brush_hold_step then
		--	minetest.chat_send_all("brush hold step was adjusted to "..(exe_time*2).." secs to help crispy potato.")
		--	brush_hold_step = exe_time*2
		--end
	end
end

cozylights.uncozy_chunk_queue = {}
cozylights.uncozy_queue_idx = 1
local UNCOZY_CHUNK_RAD = 16
local UNCOZY_STEP = UNCOZY_CHUNK_RAD * 2

cozylights.drawn_nodes = {}
minetest.register_globalstep(function(dtime)
	if wield_light_enabled then
		wield_dtime = wield_dtime + dtime
		if wield_dtime > wield_step then
			wield_dtime = 0
			for _, cozyplayer in pairs(cozylights.cozyplayers) do
				local t = os.clock()
				local player = minetest.get_player_by_name(cozyplayer.name)
				local pos = vector.round(player:get_pos())
				pos.y = pos.y + 1
				local wield_name = player:get_wielded_item():get_name()
				local current_is_light = (cozylights.cozy_items[wield_name] ~= nil)
				local prev_was_light = (cozylights.cozy_items[cozyplayer.last_wield] ~= nil)
				local pos_hash = hash_pos(pos)
				if pos_hash == cozyplayer.pos_hash and cozyplayer.last_wield == wield_name then
					goto next_player
				end
				if not current_is_light and not prev_was_light then
					cozyplayer.pos_hash = pos_hash
					cozyplayer.last_pos = pos
					cozyplayer.last_wield = wield_name
					goto next_player
				end
				if current_is_light then
					local vel = vector.round(vector.multiply(player:get_velocity(), wield_step))
					cozylights:draw_wielded_light(
						pos,
						cozyplayer.last_pos,
						cozylights.cozy_items[wield_name],
						vel,
						cozyplayer,
						wield_name
					)
				else
					cozylights:wielded_light_cleanup(player, cozyplayer, cozyplayer.last_wield_radius or 0)
				end
				cozyplayer.pos_hash = pos_hash
				cozyplayer.last_pos = pos
				cozyplayer.last_wield = wield_name
				local exe_time = (os.clock() - t)
				total_wield_time = total_wield_time + mf(exe_time * 1000)
				total_wield_step_count = total_wield_step_count + 1
				print(
					"Av wielded cozy light step time "
						.. mf(total_wield_time / total_wield_step_count)
						.. " ms. Sample of: "
						.. total_wield_step_count
				)
				if cozylights.crispy_potato and exe_time > wield_step then
					cozylights:set_wielded_light_radius(cozylights.max_wield_light_radius - 1)
					minetest.chat_send_all(
						"wield light step was adjusted to " .. (exe_time * 2) .. " secs to help crispy potato."
					)
					wield_step = exe_time * 2
				end
				::next_player::
			end
		end
	end
	brush_hold_dtime = brush_hold_dtime + dtime
	if brush_hold_dtime > brush_hold_step then
		brush_hold_dtime = 0
		for _, cozyplayer in pairs(cozylights.cozyplayers) do
			local t = os.clock()
			local player = minetest.get_player_by_name(cozyplayer.name)
			local pos = vector.round(player:get_pos())
			pos.y = pos.y + 1
			local wield_name = player:get_wielded_item():get_name()
			--todo: checking against a string is expensive, what do
			if wield_name == "cozylights:light_brush" then
				on_brush_hold(player, cozyplayer, pos, t)
			end
		end
	end
	on_gen_dtime = on_gen_dtime + dtime
	if on_gen_dtime > on_gen_step then
		on_gen_dtime = 0
		if cozylights.uncozy_mode == 0 then
			if #cozylights.area_queue ~= 0 then
				local ar = cozylights.area_queue[1]
				table.remove(cozylights.area_queue, 1)
				print("build_lights_after_generated: " .. cozylights:dump(ar.minp))
				build_lights_after_generated(ar.minp, ar.maxp, ar.sources)
			else
				cozylights:rebuild_light()
				if #cozylights.single_light_queue == 0 then
					if #cozylights.recently_updated > 0 then
						cozylights.recently_updated = {}
					end
					if next(cozylights.drawn_nodes) ~= nil then
						cozylights.drawn_nodes = {}
					end
				end
			end
		else
			for _, cozyplayer in pairs(cozylights.cozyplayers) do
				local player = minetest.get_player_by_name(cozyplayer.name)
				local pos = vector.round(player:get_pos())
				pos.y = pos.y + 1
				local last_pos = cozyplayer.last_uncozy_pos or vector.new(0, -9999, 0)
				local dist = vector.distance(pos, last_pos)
				if dist > UNCOZY_CHUNK_RAD then
					cozyplayer.last_uncozy_pos = pos
					local rad = cozylights.uncozy_mode
					for x = -rad, rad, UNCOZY_STEP do
						for y = -rad, rad, UNCOZY_STEP do
							for z = -rad, rad, UNCOZY_STEP do
								cozylights.uncozy_chunk_queue[#cozylights.uncozy_chunk_queue + 1] = {
									x = pos.x + x,
									y = pos.y + y,
									z = pos.z + z,
								}
							end
						end
					end
				end
			end
			local q = cozylights.uncozy_chunk_queue
			local idx = cozylights.uncozy_queue_idx
			if idx <= #q then
				local target_pos = q[idx]
				cozylights.uncozy_queue_idx = idx + 1
				local exe_time = cozylights:clear(target_pos, UNCOZY_CHUNK_RAD)
				if cozylights.crispy_potato and exe_time > on_gen_step then
					on_gen_step = exe_time * 2
				end
				if cozylights.uncozy_queue_idx > #q then
					cozylights.uncozy_chunk_queue = {}
					cozylights.uncozy_queue_idx = 1
				end
			end
		end
	end
end)

local gent_total = 0
local gent_count = 0
minetest.register_on_generated(function(minp, maxp)
	local light_sources = cozylights.find_nodes_in_area(minp, maxp, cozylights.source_nodes)
	if #light_sources == 0 then
		return
	end
	if #light_sources > 1000 then
		minetest.log(
			"warning",
			"[cozylights] Mapchunk at " .. cozylights:dump(minp) .. " saturated with >1000 lights. Gobbling up anyway."
		)
	end
	for _, p in ipairs(light_sources) do
		local name = cozylights.get_node(p).name
		local cozy_item = cozylights.cozy_items[name]
		local radius, _ = cozylights:calc_dims(name, cozy_item)
		cozylights.storage.set_light(p, radius, false)
	end
end)

-- when we dig the ground near a light_source
minetest.register_on_dignode(function(pos, oldnode, digger)
	if oldnode.name == "air" or minetest.registered_nodes[oldnode.name].drawtype == "liquid" then
		return
	end
	if
		cozylights.cozycids_light_sources[minetest.get_content_id(oldnode.name)]
		or oldnode.name:sub(1, 22) == "cozylights:light_debug"
	then
		return
	end
	cozylights:update_cone(pos)
end)

-- to update light maps when an obstruction is placed
if not cozylights.is_mcl then
	minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
		local nodedef = minetest.registered_nodes[newnode.name]
		if newnode.name == "air" or (nodedef and nodedef.drawtype == "liquid") then
			return
		end
		if
			cozylights.cozycids_light_sources[minetest.get_content_id(newnode.name)]
			or newnode.name:sub(1, 22) == "cozylights:light_debug"
		then
			return
		end

		cozylights:update_shadow_cone(pos)
	end)
end

--does everything except for generation that requires to check for air first
--still investigating the viability of all options considering other mods behavior
--[[minetest.register_on_mapblocks_changed(function(modified_blocks, modified_block_count)
	local queue = cozylights.area_queue
	local q_idx = #queue
	local source_nodes = cozylights.source_nodes
	local mask = cozylights.masked_mapblocks -- Localize reference
	for hash, _ in pairs(modified_blocks) do
		if mask[hash] then
			mask[hash] = nil
		else
			local blockpos = minetest.get_position_from_hash(hash)
			local minp = {
				x = blockpos.x * 16,
				y = blockpos.y * 16,
				z = blockpos.z * 16
			}
			local maxp = {
				x = minp.x + 15,
				y = minp.y + 15,
				z = minp.z + 15
			}
			local light_sources = cozylights.find_nodes_in_area(minp, maxp, source_nodes)
			if #light_sources > 0 then
				cozylights:push_area_queue(minp, maxp, nil)
			end
		end
	end
end)]]
