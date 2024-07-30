cozylights = {
	-- constant size values and tables
	version = "0.2.7",
	default_size = tonumber(minetest.settings:get("mapfix_default_size")) or 40,
	brightness_factor = tonumber(minetest.settings:get("cozylights_brightness_factor")) or 8,
	reach_factor = tonumber(minetest.settings:get("cozylights_reach_factor")) or 2,
	dim_factor = tonumber(minetest.settings:get("cozylights_dim_factor")) or 9.5,
	step_time = tonumber(minetest.settings:get("cozylights_step_time")) or 0.2,
	max_wield_light_radius = tonumber(minetest.settings:get("cozylights_wielded_light_radius")) or 19,
	override_engine_lights = minetest.settings:get_bool("cozylights_override_engine_lights", false),
	always_fix_edges = minetest.settings:get_bool("cozylights_always_fix_edges", false),
	-- this is a table of modifiers for global light source settings.
	-- lowkeylike and dimlike usually assigned to decorations in hopes to make all ambient naturally occuring light sources weaker
	-- this is for two reasons:
	-- 1. performance: never know how many various nice looking blocks which emit light will be there, or for example computing lights for
	-- every node of a lava lake would be extremely expensive if those would reach far/would be very bright
	-- 2. looks: they were made with default engine lighting in mind, so usually are very frequent, with such frequency default cozylights
	-- settings will make the environment look blunt
	coziest_table = {
		--"dimlike"
		[1] = {
			brightness_factor = 0,
			reach_factor = 0,
			dim_factor = 0
		},
		--"lowkeylike" almost the same as dimlike, but reaches much farther with its barely visible light
		[2] = {
			brightness_factor = 0,
			reach_factor = 2,
			dim_factor = -3
		},
		-- "candlelike" something-something
		[3] = {
			brightness_factor = 0,
			reach_factor = 2,
			dim_factor = -3
		},
		-- "torchlike" torches, fires, flames. made much dimmer than what default engine lights makes them
		[4] = {
			brightness_factor = -2,
			reach_factor = 0,
			dim_factor = 0
		},
		-- "lamplike" a bright source, think mese lamp(actually turned out its like a projector, and below is even bigger projector)
		[5] = {
			brightness_factor = 0,
			reach_factor = 3,
			dim_factor = 4
		},
		-- "projectorlike" a bright source with massive reach
		[6] = {
			brightness_factor = 1,
			reach_factor = 3,
			dim_factor = 4
		},
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

local total_dtime = 0
local total_step_time = 0
local total_step_count = 0

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
--ffi = require("ffi")
dofile(modpath.."/wield_light.lua")
dofile(modpath.."/node_light.lua")
dofile(modpath.."/light_brush.lua")

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
				cozy_items[def.name] = {light_source= def.light_source or 0,floodable=def.floodable or false,modifiers=mods}
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
								cozylights:destroy_light(pos, cozy_items[def.name])
							end,
						})
					else
						minetest.override_item(node,{
							on_destruct = function(pos)
								print(cozylights:dump(pos))
								print(def.name.." is destroyed1")
								cozylights:destroy_light(pos, cozy_items[def.name])
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
								cozylights:draw_node_light(pos, cozy_items[def.name])
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
								cozylights:draw_node_light(pos, cozy_items[def.name])
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
end)

--clean up possible stale wielded light on join, since on server shutdown we cant execute on_leave
--todo: make it more normal and less of a hack
function cozylights:on_join_cleanup(pos, radius)
	local vm  = minetest.get_voxel_manip()
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

minetest.register_on_joinplayer(function(player)
	if not player then return end
	local pos = vector.round(player:getpos())
	pos.y = pos.y + 1
	cozylights:on_join_cleanup(pos, 30)
	cozylights.cozyplayers[player:get_player_name()] = {
		name=player:get_player_name(),
		pos_hash=pos.x + (pos.y)*100 + pos.z*10000,
		wielded_item=0,
		last_pos=pos,
		last_wield="",
		prev_wielded_lights={},
		lbrush={
			brightness=14,
			radius=0,
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
local recently_updated = {}
local function build_lights_after_generated(minp,maxp,sources)
	local t = os.clock()
	local vm  = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(vector.subtract(minp, 1), vector.add(maxp, 1))
	local data = vm:get_data()
	local param2data = vm:get_param2_data()
	local a = VoxelArea:new{
		MinEdge = emin,
		MaxEdge = emax
	}
	if sources then
		for i=1, #sources do
			local s = sources[i]
			--local hash = minetest.hash_node_position(s.pos)
			local hash = s.pos.x + (s.pos.y)*100 + s.pos.z*10000
			if recently_updated[hash] == nil then
				recently_updated[hash] = true
				cozylights:draw_node_light(s.pos, s.cozy_item, vm, a, data, param2data)
			end
		end
	else
		local cozycids_light_sources = cozylights.cozycids_light_sources
		for i in a:iterp(minp,maxp) do
			local cid = data[i]
			if cozycids_light_sources[cid] then
				local cozy_item = cozylights.cozy_items[minetest.get_name_from_content_id(cid)]
				-- check if radius is not too big
				local radius, _ = cozylights:calc_dims(cozy_item)
				local p = a:position(i)
				if a:containsp(vector.subtract(p,radius)) and a:containsp(vector.add(p,radius))
				then
					cozylights:draw_node_light(p,cozy_item,vm,a,data,param2data)
				else
					table.insert(cozylights.single_light_queue, { pos=p, cozy_item=cozy_item })
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
local step_time = cozylights.step_time

function cozylights:switch_wielded_light(enabled)
	wield_light_enabled = enabled
end

function cozylights:set_step_time(_time)
	step_time = _time
	minetest.settings:set("cozylights_step_time",_time)
	cozylights.step_time = _time
end

--idk, size should be smarter than a constant
local size = 85
local function place_schem_but_real(pos, schematic, rotation, replacements, force_placement, flags)
	if tonumber(schematic) ~= nil or type(schematic) == "string" then -- schematic.data
		cozylights.area_queue[#cozylights.area_queue+1]={
			minp=vector.subtract(pos, size),
			maxp=vector.add(pos, size),
			sources=nil
		}
		return
	end
	local sd = schematic.data
	local update_needed = false
	for i, node in pairs(sd) do
		-- todo: account for replacements
		if cozylights.cozy_items[node.name] then
			-- rotation can be random so we cant know the position
			-- todo: account for faster cases when its not random
			update_needed = true
			break
		end
	end
	if update_needed == true then
		local cozycids_light_sources = cozylights.cozycids_light_sources
		print("UPDATE NEEDED")
		local minp,maxp,vm,data,param2data,a = cozylights:getVoxelManipData(pos, size)
		for i in a:iterp(minp, maxp) do
			local cid = data[i]
			if cozycids_light_sources[cid] then
				local cozy_item = cozylights.cozy_items[minetest.get_name_from_content_id(cid)]
				-- check if radius is not too big
				local radius, _ = cozylights:calc_dims(cozy_item)
				local p = a:position(i)
				if a:containsp(vector.subtract(p,radius)) and a:containsp(vector.add(p,radius))
				then
					cozylights:draw_node_light(p,cozy_item,vm,a,data,param2data)
				else
					table.insert(cozylights.single_light_queue, { pos=p, cozy_item=cozy_item })
				end
			end
		end
		cozylights:setVoxelManipData(vm,data,param2data,true)
	end
end

--a feeble attempt to cover schematics placements
local placeschemthatisnotreal = minetest.place_schematic
--todo: if its a village(several schematics) dont rebuild same lights
--todo: schematic exception table, if we have discovered for a fact somehow that a particular schematic
--cant possibly have any kind of lights then we ignore
--if not in runtime, then a constant table,
--might require additional tools to load all schematics on contentdb to figure this out
local schem_queue = {}
minetest.place_schematic = function(pos, schematic, rotation, replacements, force_placement, flags)
	if not placeschemthatisnotreal(pos, schematic, rotation, replacements, force_placement, flags) then return end
	-- now totally real stuff starts to happen
	schem_queue[#schem_queue+1] = {
		pos = pos,
		schematic = schematic,
		rotation = rotation,
		replacements = replacements,
		force_placement = force_placement,
		flags = flags
	}
end

local place_schematic_on_vmanip_nicely = minetest.place_schematic_on_vmanip
minetest.place_schematic_on_vmanip = function(vmanip, minp, filename, rotation, replacements, force_placement,flags)
	if not place_schematic_on_vmanip_nicely(vmanip, minp, filename, rotation, replacements, force_placement,flags) then return end
	schem_queue[#schem_queue+1] = {
		pos = minp,
		schematic = filename,
		rotation = rotation,
		replacements = replacements,
		force_placement = force_placement,
		flags = flags
	}
end

local createschemthatisveryreadable = minetest.create_schematic
minetest.create_schematic = function(p1, p2, probability_list, filename, slice_prob_list)
	if not createschemthatisveryreadable(p1, p2, probability_list, filename, slice_prob_list) then return end
	-- unreadable stuff happens here
	cozylights.area_queue[#cozylights.area_queue+1] = {
		minp = p1,
		maxp = p2,
		sources = nil
	}
end


local function on_brush_hold(player,cozyplayer,pos)
	local control_bits = player:get_player_control_bits()
	if control_bits < 128 or control_bits >= 256 then return end
	local lb = cozyplayer.lbrush
	if lb.radius > 30 then return end
	local look_dir = player:get_look_dir()
	local endpos = vector.add(pos, vector.multiply(look_dir, 100))
	local hit = minetest.raycast(pos, endpos, false, false):next()
	if not hit then return end
	local nodenameunder = minetest.get_node(hit.under).name
	local nodedefunder = minetest.registered_nodes[nodenameunder]
	local above = hit.above
	if nodedefunder.buildable_to == true then
		above.y = above.y - 1
	end
	local above_hash = above.x + (above.y)*100 + above.z*10000
	if above_hash ~= lb.pos_hash or lb.mode == 2 or lb.mode == 4 or lb.mode == 5 then
		lb.pos_hash = above_hash
		cozylights:draw_brush_light(above, lb)
	end
end

local light_build_time = 0
minetest.register_globalstep(function(dtime)
	total_dtime = total_dtime + dtime
	if total_dtime > step_time then
		total_dtime = 0
		light_build_time = light_build_time + step_time
		if light_build_time > step_time*5 then
			light_build_time = 0
			if #schem_queue > 0 then
				local s = schem_queue[1]
				place_schem_but_real(s.pos, s.schematic, s.rotation, s.replacements, s.force_placement, s.flags)
				table.remove(schem_queue, 1)
			end
			if #cozylights.area_queue ~= 0 then
				local ar = cozylights.area_queue[1]
				table.remove(cozylights.area_queue, 1)
				print("build_lights_after_generated: "..cozylights:dump(ar.minp))
				build_lights_after_generated(ar.minp,ar.maxp,ar.sources)
			else
				cozylights:rebuild_light()
				if #recently_updated > 0 then
					recently_updated = {}
				end
			end
		end
		local t = os.clock()
		for _,cozyplayer in pairs(cozylights.cozyplayers) do
			local player = minetest.get_player_by_name(cozyplayer.name)
			local pos = vector.round(player:getpos())
			pos.y = pos.y + 1
			local wield_name = player:get_wielded_item():get_name()
			--todo: checking against a string is expensive, what do
			if wield_name == "cozylights:light_brush" then
				on_brush_hold(player,cozyplayer,pos)
			end

			if wield_light_enabled == false then
				goto next_player
			end
			-- simple hash, collision will result in a rare minor barely noticeable glitch if a user teleports:
			-- if in collision case right after teleport the player does not move, wielded light wont work until the player starts moving 		
			local pos_hash = pos.x + (pos.y)*100 + pos.z*10000
			if pos_hash == cozyplayer.pos_hash and cozyplayer.last_wield == wield_name then
				goto next_player
			end
			if cozylights.cozy_items[wield_name] ~= nil then
				local vel = vector.round(vector.multiply(player:get_velocity(),step_time))
				cozylights:draw_wielded_light(
					pos,
					cozyplayer.last_pos,
					cozylights.cozy_items[wield_name],
					vel,
					cozyplayer
				)
			else
				cozylights:wielded_light_cleanup(player,cozyplayer,cozyplayer.last_wield_radius or 0)
			end
			cozyplayer.pos_hash = pos_hash
			cozyplayer.last_pos = pos
			cozyplayer.last_wield = wield_name
			total_step_time = total_step_time + mf((os.clock() - t) * 1000)
			total_step_count = total_step_count + 1
			--print("Av wielded cozy light step time " .. mf(total_step_time/total_step_count) .. " ms. Sample of: "..total_step_count)
			::next_player::
		end
	end
end)

local gent_total = 0
local gent_count = 0
minetest.register_on_generated(function(minp, maxp)
	local pos = vector.add(minp, vector.floor(vector.divide(vector.subtract(maxp,minp), 2)))
	local light_sources = minetest.find_nodes_in_area(minp,maxp,cozylights.source_nodes)
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
		local name = minetest.get_node(p).name--get_name_from_content_id(cid)
		local cozy_item = cozylights.cozy_items[name]
		local radius, _ = cozylights:calc_dims(cozy_item)
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
		cozylights.area_queue[#cozylights.area_queue+1]={
			minp=minp_exp,
			maxp=maxp_exp,
			sources=sources
		}
	end
end)

