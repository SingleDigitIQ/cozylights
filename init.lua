cozylights = {
	-- constant size values and tables
	version = "0.2.10",
	default_size = tonumber(minetest.settings:get("mapfix_default_size")) or 40,

	global_brightness = tonumber(minetest.settings:get("cozylights_global_brightness")) or 12,
	global_radius = tonumber(minetest.settings:get("cozylights_global_radius")) or 15,
	global_strength = tonumber(minetest.settings:get("cozylights_global_strength")) or 0.5,

	brightness_factor = tonumber(minetest.settings:get("cozylights_brightness_factor")) or 8,
	wield_step = tonumber(minetest.settings:get("cozylights_wield_step")) or 0.03,
	brush_hold_step = tonumber(minetest.settings:get("cozylights_brush_hold_step")) or 0.07,
	on_gen_step = tonumber(minetest.settings:get("cozylights_on_gen_step")) or 0.7,
	max_wield_light_radius = tonumber(minetest.settings:get("cozylights_wielded_light_radius")) or 15,
	override_engine_lights = minetest.settings:get_bool("cozylights_override_engine_lights", false),
	always_fix_edges = minetest.settings:get_bool("cozylights_always_fix_edges", false),
	uncozy_mode = tonumber(minetest.settings:get("cozylights_uncozy_mode")) or 0,
	crispy_potato = minetest.settings:get_bool("cozylights_crispy_potato", true),
	-- this is a table of modifiers for global light source settings.
	-- lowkeylike and dimlike usually assigned to decorations in hopes to make all ambient naturally occuring light sources weaker
	-- this is for two reasons:
	-- 1. performance: never know how many various nice looking blocks which emit light will be there, or for example computing lights for
	-- every node of a lava lake would be extremely expensive if those would reach far/would be very bright
	-- 2. looks: they were made with default engine lighting in mind, so usually are very frequent, with such frequency default cozylights
	-- settings will make the environment look blunt
	coziest_table = {
		--"dimlike"
		[1] = { brightness = -4, radius = 4, strength = -0.1 },
		--"lowkeylike"
		[2] = { brightness = -2, radius = 8, strength = 0.0 },
		-- "candlelike"
		[3] = { brightness = -1, radius = 6, strength = 0.0 },
		-- "torchlike"
		[4] = { brightness = 0, radius = 12, strength = 0.1 },
		-- "lamplike"
		[5] = { brightness = 1, radius = 18, strength = 0.1 },
		-- "projectorlike"
		[6] = { brightness = 2, radius = 25, strength = 0.2 },
	},
	-- appears nodes and items might not necessarily be the same array
	source_nodes = nil,
	cozy_items = nil,
	-- dynamic size tables, okay now what about functions
	cozycids_sunlight_propagates = {},
	cozycids_light_sources = {},
	cozyplayers = {},
	area_queue = {},
	single_light_queue = {},
	modpath = minetest.get_modpath(minetest.get_current_modname())
}

local modpath = minetest.get_modpath(minetest.get_current_modname())
dofile(modpath.."/helpers.lua")

-- backrooms test attempts to resolve mt engine lights problem with invisible lights, default settings will result
-- in many places being very well lit
-- me thinks ideal scenery with cozy lights in particular can be achieved with removal of all invisible lights
-- it also looks interesting after maybe a two thirds of light sources are broken
-- however the backrooms idea is not about broken windows theory at all, more about supernatural absence of any life
-- in a seemingly perfectly functioning infinite manmade mess, or idk i am not mentally masturbating any further,
-- some of the internets do that way too often, way too much
if cozylights:mod_loaded("br_core") then
	cozylights.brightness_factor = cozylights.brightness_factor - 6
end

dofile(modpath.."/nodes.lua")
dofile(modpath.."/shared.lua")
dofile(modpath.."/chat_commands.lua")
dofile(modpath.."/wield_light.lua")
dofile(modpath.."/node_light.lua")
dofile(modpath.."/light_brush.lua")
dofile(modpath.."/api_overrides.lua")
dofile(modpath.."/manual.lua")

local c_air = minetest.get_content_id("air")
local c_light1 = minetest.get_content_id("cozylights:light1")

local c_lights = { c_light1, c_light1 + 1, c_light1 + 2, c_light1 + 3, c_light1 + 4, c_light1 + 5, c_light1 + 6,
	c_light1 + 7, c_light1 + 8, c_light1 + 9, c_light1 + 10, c_light1 + 11, c_light1 + 12, c_light1 + 13 }

local mf = math.floor

------------------------------------------

minetest.register_on_mods_loaded(function()
	local source_nodes = {}
	local cozy_items = {}
	local cozycids_sunlight_propagates = {}
	local cozycids_light_sources = {}
	local override = cozylights.override_engine_lights
	for _,def in pairs(minetest.registered_items) do
		if def.light_source and def.light_source > 1
			and def.drawtype ~= "airlike" and def.drawtype ~= "liquid"
			and string.find(def.name, "lava_flowing") == nil
			and string.find(def.name, "lava_source") == nil
			--and def.liquid_renewable == nil and def.drowning == nil
		then
			-- here we are going to define more specific skips and options for sus light sources
			local skip = false
			if string.find(def.name, "everness:") ~= nil and def.groups.vine ~= nil then
				skip = true -- like goto continue
			end
			if skip == false then
				local mods = nil
				--if def.drawtype == "plantlike" then
				--	mods = 1
				--end
				--if string.find(def.name,"torch") then
				--	mods = 3
				--end
				cozy_items[def.name] = {name = def.name,light_source= def.light_source or 0,floodable=def.floodable or false,modifiers=mods}
				if not string.find(def.name, "cozylights:light") then
					source_nodes[#source_nodes+1] = def.name
				end
			end
		end
	end
	for node,def in pairs(minetest.registered_nodes) do
		if def.sunlight_propagates == true then
			local cid = minetest.get_content_id(def.name)
			cozycids_sunlight_propagates[cid] = true
		end
		if def.light_source and def.light_source > 1
			and def.drawtype ~= "airlike" and def.drawtype ~= "liquid"
			and not string.find(def.name, "lava_flowing")
			and not string.find(def.name, "lava_source")
			--and def.liquid_viscosity == nil and def.liquid_renewable == nil and def.drowning == nil
		then
			local cid = minetest.get_content_id(def.name)
			if cid < c_lights[1] or cid > c_lights[14]+14 then
				local skip = false
				if string.find(def.name, "everness:") ~= nil and def.groups.vine ~= nil then
					skip = true -- like goto :continue:
				end
				if skip == false then
					cozycids_light_sources[cid] = true
					if def.on_destruct then
						local base_on_destruct = def.on_destruct
						minetest.override_item(node,{
							on_destruct = function(pos)
								base_on_destruct(pos)
								print(cozylights:dump(pos))
								print(def.name.." is destroyed")
								cozylights:destroy_light(pos, cozy_items[def.name],def.name)
							end,
						})
					else
						minetest.override_item(node,{
							on_destruct = function(pos)
								print(cozylights:dump(pos))
								print(def.name.." is destroyed1")
								cozylights:destroy_light(pos, cozy_items[def.name],def.name)
							end,
						})
					end
					if def.on_construct ~= nil then
						local base_on_construct = def.on_construct
						local light = override == true and 1 or def.light_source
						if def.name == "br_core:ceiling_light_1" then
							light = def.light_source - 7
						end
						minetest.override_item(node,{
							light_source = light,
							use_texture_alpha= def.use_texture_alpha or "clip",
							on_construct = function(pos)
								base_on_construct(pos)
								cozylights:draw_node_light(pos, cozy_items[def.name],def.name)
							end,
						})
					else
						local light = override == true and 1 or def.light_source
						if def.name == "br_core:ceiling_light_1" then
							light = def.light_source - 7
						end
						minetest.override_item(node,{
							light_source = light,
							use_texture_alpha= def.use_texture_alpha or "clip",
							on_construct = function(pos)
								cozylights:draw_node_light(pos, cozy_items[def.name],def.name)
							end,
						})
					end
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
                            local p_above = {x = pointed_thing.under.x, y = pointed_thing.under.y + 1, z = pointed_thing.under.z}
                            local above_node = cozylights.get_node(p_above)
                            if above_node and string.find(above_node.name, "cozylights:light", 1, true) then
                                minetest.remove_node(p_above)
								cozylights:push_area_queue(p_above, p_above, nil)
                            end
                        end
                        return orig_on_use(itemstack, user, pointed_thing)
                    end
                })
            end
            if def.on_place then
                local orig_on_place = def.on_place
                minetest.override_item(name, {
                    on_place = function(itemstack, placer, pointed_thing)
                        if pointed_thing and pointed_thing.type == "node" then
                            local p_above = {x = pointed_thing.under.x, y = pointed_thing.under.y + 1, z = pointed_thing.under.z}
                            local above_node = cozylights.get_node(p_above)
                            if above_node and string.find(above_node.name, "cozylights:light", 1, true) then
                                minetest.remove_node(p_above)
								cozylights:push_area_queue(p_above, p_above, nil)
                            end
                        end
                        return orig_on_place(itemstack, placer, pointed_thing)
                    end
                })
            end
        end
    end
	-- more or less fast light rebuild
	cozylights.rebuild_bounds = {}
	for name, item in pairs(cozylights.cozy_items) do
		local r, _ = cozylights:calc_dims(name,item)
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
	local vm  = cozylights.get_voxel_manip()
	local emin, emax = vm:read_from_map(vector.subtract(pos, radius+1), vector.add(pos, radius+1))
	local data = vm:get_data()
	local a = VoxelArea:new{
		MinEdge = emin,
		MaxEdge = emax
	}
	local param2data = vm:get_param2_data()
	local max_radius = radius * (radius + 1)
	for z = -radius, radius do
		for y = -radius, radius do
			for x = -radius, radius do
				--local p = vector.add(pos,{x=x,y=y,z=z})
				local p = {x=x+pos.x,y=y+pos.y,z=z+pos.z}
				local idx = a:indexp(p)
				local squared = x * x + y * y + z * z
				if data[idx] >= c_lights[1] and data[idx] <= c_lights[14] and param2data[idx] == 0 and squared <= max_radius then
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
	if not player then return end
	local pos = vector.round(player:getpos())
	pos.y = pos.y + 1
	cozylights:on_join_cleanup(pos, 30)
	local meta = player:get_meta()
	if meta:get_int("cozylights_manual_issued") == 0 then
		local inv = player:get_inventory()
		if inv:room_for_item("main", "cozylights:alpha_manual") then
			inv:add_item("main", "cozylights:alpha_manual")
			meta:set_int("cozylights_manual_issued", 1)
		else
			minetest.log("warning", "[cozylights] Failed to issue alpha manual to " .. player:get_player_name() .. " - Inventory saturated.")
		end
	end
	cozylights.cozyplayers[player:get_player_name()] = {
		name=player:get_player_name(),
		pos_hash=hash_pos(pos),
		wielded_item=0,
		last_pos=pos,
		last_wield="",
		prev_wielded_lights={},
		lbrush={
			brightness=14,
			radius=80,
			strength=0.5,
			mode=1,
			cover_only_surfaces=0,
			pos_hash=0,
		}
	}
end)
minetest.register_on_leaveplayer(function(player)
	if not player then return end
	local name = player:get_player_name()
	for i=1,#cozylights.cozyplayers do
		if cozylights.cozyplayers[i].name == name then
			cozylights:wielded_light_cleanup(player,cozylights.cozyplayers[i],30)
			table.remove(cozylights.cozyplayers,i)
		end
	end
end)

minetest.register_on_shutdown(function()
	for i=1,#cozylights.cozyplayers do
		local player = minetest.get_player_by_name(cozylights.cozyplayers[i].name)
		if player ~= nil then
			cozylights:wielded_light_cleanup(player,cozylights.cozyplayers[i],30)
		end
	end
end)

local agent_total = 0
local agent_count = 0
cozylights.recently_updated = {}

function cozylights:push_area_queue(minp, maxp, sources)
	local queue = self.area_queue
	local area_hash = minp.x + (minp.y * 100) + (minp.z * 10000)
	if self.recently_updated[area_hash] then
		return false
	end
	for i = 1, #queue do
		local q = queue[i]
		if minp.x <= q.maxp.x and maxp.x >= q.minp.x and
		   minp.y <= q.maxp.y and maxp.y >= q.minp.y and
		   minp.z <= q.maxp.z and maxp.z >= q.minp.z then
			return false
		end
	end
	queue[#queue + 1] = {
		minp = minp,
		maxp = maxp,
		sources = sources
	}
	return true
end

local function build_lights_after_generated(minp, maxp, sources)
	local t = os.clock()
	local vm  = cozylights.get_voxel_manip()
	local emin, emax = vm:read_from_map(vector.subtract(minp, 1), vector.add(maxp, 1))
	local data = vm:get_data()
	local param2data = vm:get_param2_data()
	local a = VoxelArea:new{
		MinEdge = emin,
		MaxEdge = emax
	}
	local recently_updated = cozylights.recently_updated
	if sources then
		for i=1, #sources do
			local s = sources[i]
			local hash = hash_pos(s.pos)
			if not recently_updated[hash] then
				recently_updated[hash] = true
				cozylights:draw_node_light(s.pos, s.cozy_item, s.cozy_item.name, vm, a, data, param2data)
			end
		end
	else
		local cozycids_light_sources = cozylights.cozycids_light_sources
		for i in a:iterp(minp,maxp) do
			local cid = data[i]
			if cozycids_light_sources[cid] then
				local p = a:position(i)
				local hash = hash_pos(p)
				if not recently_updated[hash] then
					recently_updated[hash] = true
					local name = minetest.get_name_from_content_id(cid)
					local cozy_item = cozylights.cozy_items[name]
					local radius, _ = cozylights:calc_dims(name, cozy_item)
					if a:containsp(vector.subtract(p,radius)) and a:containsp(vector.add(p,radius)) then
						cozylights:draw_node_light(p,cozy_item,cozy_item.name,vm,a,data,param2data)
					else
						table.insert(cozylights.single_light_queue, { pos=p, cozy_item=cozy_item })
					end
				end
			end
		end
	end
	cozylights:setVoxelManipData(vm,data,param2data,true)
	agent_total = agent_total + mf((os.clock() - t) * 1000)
	agent_count = agent_count + 1
	print("Av build after generated time: "..
		mf(agent_total/agent_count).." ms. Sample of: "..agent_count..". Areas left: "..#cozylights.area_queue
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
	minetest.settings:set("cozylights_wield_step",_time)
	cozylights.wield_step = _time
end

function cozylights:set_brush_hold_step(_time)
	brush_hold_step = _time
	minetest.settings:set("cozylights_brush_hold_step",_time)
	cozylights.brush_hold_step = _time
end

function cozylights:set_on_gen_step(_time)
	on_gen_step = _time
	minetest.settings:set("cozylights_on_gen_step",_time)
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

local function on_brush_hold(player,cozyplayer,pos,t)
	local control_bits = player:get_player_control_bits()
	if control_bits < 128 or control_bits >= 256 then return end
	local lb = cozyplayer.lbrush
	if lb.radius > 10 then return end
	local look_dir = player:get_look_dir()
	local endpos = vector.add(pos, vector.multiply(look_dir, 100))
	local hit = minetest.raycast(pos, endpos, false, false):next()
	if not hit then return end
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
		print("Av cozy lights brush step time " .. mf(total_brush_hold_time/total_brush_hold_step_count) .. " ms. Sample of: "..total_brush_hold_step_count)
		--if exe_time > brush_hold_step then
		--	minetest.chat_send_all("brush hold step was adjusted to "..(exe_time*2).." secs to help crispy potato.")
		--	brush_hold_step = exe_time*2
		--end
	end
end

cozylights.drawn_nodes = {}
minetest.register_globalstep(function(dtime)
	if wield_light_enabled then
		wield_dtime = wield_dtime + dtime
		if wield_dtime > wield_step then
			wield_dtime = 0
			for _,cozyplayer in pairs(cozylights.cozyplayers) do
				local t = os.clock()
				local player = minetest.get_player_by_name(cozyplayer.name)
				local pos = vector.round(player:getpos())
				pos.y = pos.y + 1
				local wield_name = player:get_wielded_item():get_name()
				-- simple hash, collision will result in a rare minor barely noticeable glitch if a user teleports:
				-- if in collision case right after teleport the player does not move, wielded light wont work until the player starts moving
				local pos_hash = hash_pos(pos)
				if pos_hash == cozyplayer.pos_hash and cozyplayer.last_wield == wield_name then
					goto next_player
				end
				if cozylights.cozy_items[wield_name] ~= nil then
					local vel = vector.round(vector.multiply(player:get_velocity(),wield_step))
					cozylights:draw_wielded_light(
						pos,
						cozyplayer.last_pos,
						cozylights.cozy_items[wield_name],
						vel,
						cozyplayer,
						wield_name
					)
				else
					cozylights:wielded_light_cleanup(player,cozyplayer,cozyplayer.last_wield_radius or 0)
				end
				cozyplayer.pos_hash = pos_hash
				cozyplayer.last_pos = pos
				cozyplayer.last_wield = wield_name
				local exe_time = (os.clock() - t)
				total_wield_time = total_wield_time + mf(exe_time * 1000)
				total_wield_step_count = total_wield_step_count + 1
				print("Av wielded cozy light step time " .. mf(total_wield_time/total_wield_step_count) .. " ms. Sample of: "..total_wield_step_count)
				if cozylights.crispy_potato and exe_time > wield_step then
					cozylights:set_wielded_light_radius(cozylights.max_wield_light_radius - 1)
					minetest.chat_send_all("wield light step was adjusted to "..(exe_time*2).." secs to help crispy potato.")
					wield_step = exe_time*2
				end
				::next_player::
			end
		end
	end
	brush_hold_dtime = brush_hold_dtime + dtime
	if brush_hold_dtime > brush_hold_step then
		brush_hold_dtime = 0
		for _,cozyplayer in pairs(cozylights.cozyplayers) do
			local t = os.clock()
			local player = minetest.get_player_by_name(cozyplayer.name)
			local pos = vector.round(player:getpos())
			pos.y = pos.y + 1
			local wield_name = player:get_wielded_item():get_name()
			--todo: checking against a string is expensive, what do
			if wield_name == "cozylights:light_brush" then
				on_brush_hold(player,cozyplayer,pos,t)
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
				print("build_lights_after_generated: "..cozylights:dump(ar.minp))
				build_lights_after_generated(ar.minp,ar.maxp,ar.sources)
			else
				cozylights:rebuild_light()
				if #cozylights.recently_updated > 0 then
					cozylights.recently_updated = {}
				end
				if next(cozylights.drawn_nodes) ~= nil then cozylights.drawn_nodes = {} end
			end
		else
			for _,cozyplayer in pairs(cozylights.cozyplayers) do
				local player = minetest.get_player_by_name(cozyplayer.name)
				local pos = vector.round(player:getpos())
				pos.y = pos.y + 1
				-- simple hash, collision will result in a rare minor barely noticeable glitch if a user teleports:
				-- if in collision case right after teleport the player does not move, wielded light wont work until the player starts moving
				local pos_hash = hash_pos(pos)
				if pos_hash == cozyplayer.pos_hash then
					goto next_player
				end
				cozyplayer.pos_hash = pos_hash
				cozyplayer.last_pos = pos
				uncozy_queue[#uncozy_queue+1] = pos
				::next_player::
			end
			if #uncozy_queue > 0 then
				local exe_time = cozylights:clear(uncozy_queue[1], cozylights.uncozy_mode)
				table.remove(uncozy_queue, 1)
				if cozylights.crispy_potato and exe_time > on_gen_step then
					minetest.chat_send_all("on_generated step was adjusted to "..(exe_time*2).." secs to help crispy potato.")
					on_gen_step = exe_time*2
				end
			end
		end
	end
end)

local gent_total = 0
local gent_count = 0
minetest.register_on_generated(function(minp, maxp)
	local pos = vector.add(minp, vector.floor(vector.divide(vector.subtract(maxp,minp), 2)))
	local light_sources = cozylights.find_nodes_in_area(minp,maxp,cozylights.source_nodes)
	if #light_sources == 0 then return end
	if #light_sources > 1000 then
		print("Error: too many light sources around "..cozylights:dump(pos).." Report this to Cozy Lights dev")
		return
	end
	--local minp_exp,maxp_exp,_,data,_,a = cozylights:getVoxelManipData(pos, size)
	--local t = os.clock()
	local sources = {}
	local a = VoxelArea:new{
		MinEdge = minp,
		MaxEdge = maxp
	}
	local minp_exp, maxp_exp = minp, maxp
	for _, p in pairs(light_sources) do
		local name = cozylights.get_node(p).name--get_name_from_content_id(cid)
		local cozy_item = cozylights.cozy_items[name]
		local radius, _ = cozylights:calc_dims(name, cozy_item)
		local min_rad = vector.subtract(p,radius)
		local max_rad = vector.add(p,radius)
		if a:containsp(min_rad) and a:containsp(max_rad) then
			sources[#sources+1] = {
				pos=p,
				cozy_item=cozy_item
			}
		else
			minp_exp = {
				x = minp_exp.x > min_rad.x and min_rad.x or minp_exp.x,
				y = minp_exp.y > min_rad.y and min_rad.y or minp_exp.y,
				z = minp_exp.z > min_rad.z and min_rad.z or minp_exp.z,
			}
			maxp_exp = {
				x = maxp_exp.x < max_rad.x and max_rad.x or maxp_exp.x,
				y = maxp_exp.y < max_rad.y and max_rad.y or maxp_exp.y,
				z = maxp_exp.z < max_rad.z and max_rad.z or maxp_exp.z,
			}

			a = VoxelArea:new{
				MinEdge = minp_exp,
				MaxEdge = maxp_exp
			}
			sources[#sources+1] = {
				pos=p,
				cozy_item=cozy_item
			}
			--print("adding "..name.." to single_light_queue")
			--table.insert(cozylights.single_light_queue, {
			--	pos=p,
			--	cozy_item=cozy_item
			--})
		end
	end
	--gent_total = gent_total + mf((os.clock() - t) * 1000)
	--gent_count = gent_count + 1
	--print("Av mapchunk generation time " .. mf(gent_total/gent_count) .. " ms. Sample of: "..gent_count)
	if #sources > 0 then
		print("on_generated adding area:"..cozylights:dump({minp=minp_exp,maxp=maxp_exp, volume=a:getVolume()}))
		cozylights:push_area_queue(minp_exp, maxp_exp, sources)
	end
end)

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

-- when we dig the ground near a light_source
minetest.register_on_dignode(function(pos, oldnode, digger)
	if oldnode.name == "air" or minetest.registered_nodes[oldnode.name].drawtype == "liquid" then
		return
	end
	if cozylights.cozycids_light_sources[minetest.get_content_id(oldnode.name)] then
		return
	end
	cozylights:update_cone(pos)
end)

-- to update light maps when an obstruction is placed
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	local nodedef = minetest.registered_nodes[newnode.name]
	if newnode.name == "air" or (nodedef and nodedef.drawtype == "liquid") then
		return
	end
	if cozylights.cozycids_light_sources[minetest.get_content_id(newnode.name)] then
		return
	end
	local sources_to_rebuild = {}
	for bound, nodenames in pairs(cozylights.rebuild_bounds) do
		local s_minp = vector.subtract(pos, bound)
		local s_maxp = vector.add(pos, bound)
		local found = cozylights.find_nodes_in_area(s_minp, s_maxp, nodenames)
		for i = 1, #found do
			local source_pos = found[i]
			local node = cozylights.get_node(source_pos)
			local cozy_item = cozylights.cozy_items[node.name]
			if cozy_item then
				local radius, _ = cozylights:calc_dims(node.name,cozy_item)
				local V = vector.subtract(pos, source_pos)
				local D_sq = V.x*V.x + V.y*V.y + V.z*V.z
				if D_sq <= radius * radius and D_sq > 0 then
					sources_to_rebuild[#sources_to_rebuild + 1] = {
						pos = source_pos,
						cozy_item = cozy_item
					}
				end
			end
		end
	end
	if #sources_to_rebuild > 0 then
		local tx_locks = {}
		for i = 1, #sources_to_rebuild do
			local hash = hash_pos(sources_to_rebuild[i].pos)
			tx_locks[hash] = true
		end
		for i = 1, #sources_to_rebuild do
			local src = sources_to_rebuild[i]
			cozylights:destroy_light(src.pos, src.cozy_item,src.cozy_item.name, tx_locks)
			cozylights.single_light_queue[#cozylights.single_light_queue + 1] = src
		end
		cozylights:rebuild_light()
	end
end)
