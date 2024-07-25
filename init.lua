cozylights = {
	-- constant size values and tables
	version = "0.2.5",
	default_size = tonumber(minetest.settings:get("mapfix_default_size")) or 40,
	brightness_factor = tonumber(minetest.settings:get("cozylights_brightness_factor")) or 8,
	reach_factor = tonumber(minetest.settings:get("cozylights_reach_factor")) or 2,
	dim_factor = tonumber(minetest.settings:get("cozylights_dim_factor")) or 9.5,
	step_time = tonumber(minetest.settings:get("cozylights_step_time")) or 0.1,
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
	cozyplayers = {},
	area_queue = {},
	single_light_queue = {},
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
				skip = true -- like goto :continue:
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
							--tiles = {"test.png"},
							light_source = light,
							use_texture_alpha= def.use_texture_alpha or "clip",
							--on_place = function(cozy_itemstack, placer, pointed_thing)
							on_construct = function(pos)
								--local nodenameunder = minetest.get_node(pointed_thing.under).name
								--local nodedefunder = minetest.registered_nodes[nodenameunder]
								base_on_construct(pos)
								print(def.name)
								cozylights:draw_node_light(pos, cozy_items[def.name])
								--if nodenameunder ~= "air" and nodedefunder.buildable_to == true then
								--	pointed_thing.above.y = pointed_thing.above.y - 1
								--	cozylights:draw_node_light(pointed_thing.above, cozy_items[def.name])
								--else
								--	cozylights:draw_node_light(pointed_thing.above, cozy_items[def.name])
								--end
							end,
						})
					else
						local light = override == true and 1 or def.light_source
						if def.name == "br_core:ceiling_light_1" then
							light = def.light_source - 7
						end
						minetest.override_item(node,{
							--tiles = {"test.png"},
							light_source = light,
							use_texture_alpha= def.use_texture_alpha or "clip",
							--on_place = function(cozy_itemstack, placer, pointed_thing)
							on_construct = function(pos)
								--local nodenameunder = minetest.get_node(pointed_thing.under).name
								--local nodedefunder = minetest.registered_nodes[nodenameunder]
								print(def.name)
								cozylights:draw_node_light(pos, cozy_items[def.name])
								--if nodenameunder ~= "air" and nodedefunder.buildable_to == true then
								--	pointed_thing.above.y = pointed_thing.above.y - 1
								--	cozylights:draw_node_light(pointed_thing.above, cozy_items[cozy_itemstack:get_definition().name])
								--else
								--	cozylights:draw_node_light(pointed_thing.above, cozy_items[cozy_itemstack:get_definition().name])
								--end
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

local function build_lights_after_generated(minp,maxp,sources)
	local vm  = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(vector.subtract(minp, 1), vector.add(maxp, 1))
	local data = vm:get_data()
	local param2data = vm:get_param2_data()
	local a = VoxelArea:new{
		MinEdge = emin,
		MaxEdge = emax
	}
	for i=1, #sources do
		cozylights:draw_node_light(sources[i].pos,sources[i].cozy_item,vm,a,data,param2data)
	end
	cozylights:setVoxelManipData(vm,data,param2data,true)
end

local wield_light_enabled = cozylights.max_wield_light_radius > -1 and true or false

function cozylights:switch_wielded_light(enabled)
	wield_light_enabled = enabled
end

local step_time = cozylights.step_time

function cozylights:set_step_time(_time)
	step_time = _time
	minetest.settings:set("cozylights_step_time",_time)
	cozylights.step_time = _time
end

local light_build_time = 0
minetest.register_globalstep(function(dtime)
	total_dtime = total_dtime + dtime
	if total_dtime > step_time then
		total_dtime = 0
		light_build_time = light_build_time + step_time
		if light_build_time > step_time*2 then
			light_build_time = 0
			if #cozylights.area_queue ~= 0 then
				local ar = cozylights.area_queue[1]
				table.remove(cozylights.area_queue, 1)
				print("build_lights_after_generated")
				build_lights_after_generated(ar.minp,ar.maxp,ar.sources)
			else
				cozylights:rebuild_light()
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
				local control_bits = player:get_player_control_bits()
				if control_bits >= 128 and control_bits < 256 then
					local lb = cozyplayer.lbrush
					if lb.radius < 31 then
						local look_dir = player:get_look_dir()
						local endpos = vector.add(pos, vector.multiply(look_dir, 100))
						local hit = minetest.raycast(pos, endpos, false, false):next()
						if hit then
							local nodenameunder = minetest.get_node(hit.under).name
							local nodedefunder = minetest.registered_nodes[nodenameunder]
							local above = hit.above
							if nodedefunder.buildable_to == true then
								above.y = above.y - 1
							end
							local above_hash = above.x + (above.y)*100 + above.z*10000
							if lb.mode == 2 or lb.mode == 4 or lb.mode == 5 or above_hash ~= lb.pos_hash then
								lb.pos_hash = above_hash
								cozylights:draw_brush_light(above, lb)
							end
						end
					end
				end
			end
			if wield_light_enabled == true then
				-- simple hash, collision will result in a rare minor barely noticeable glitch if a user teleports:
				-- if in collision case right after teleport the player does not move, wielded light wont work until the player starts moving 		
				local pos_hash = pos.x + (pos.y)*100 + pos.z*10000
				if pos_hash ~= cozyplayer.pos_hash or cozyplayer.last_wield ~= wield_name then
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
					--print("Average wielded cozy light step time " .. mf(total_step_time/total_step_count) .. " ms. Sample of: "..total_step_count)
				end
			end
		end
	end
end)

local gent_total = 0
local gent_count = 0
minetest.register_on_generated(function(minp, maxp, seed)
	local pos = vector.add(minp, vector.floor(vector.divide(vector.subtract(maxp,minp), 2)))
	local light_sources = minetest.find_nodes_in_area(minp,maxp,cozylights.source_nodes)
	if #light_sources == 0 then
		return
	end
	minetest.chat_send_all("radius x is: "..mf((maxp.x-minp.x)/2))
	minetest.chat_send_all("radius y is: "..mf((maxp.y-minp.y)/2))
	minetest.chat_send_all("radius z is: "..mf((maxp.z-minp.z)/2))
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local t = os.clock()
	local sources = {}
	local minp_exp,maxp_exp = minp, maxp
	local a = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local data = vm:get_data()
	for _, p in pairs(light_sources) do
	--for i in a:iterp(minp, maxp) do
		local i = a:indexp(p)
		local cid = data[i]
		if cozylights.cozycids_light_sources[cid] == true then
			local name = minetest.get_name_from_content_id(cid)
			local cozy_item = cozylights.cozy_items[name]
			--local pos = a:position(i)
			local radius, _ = cozylights:calc_dims(cozy_item)
			print(name)
			if a:containsp(vector.subtract(p,radius)) and a:containsp(vector.add(p,radius)) then
				print("adding "..name.." to area_queue")
				sources[#sources+1] = {
					--pos=pos,
					pos=p,
					cozy_item=cozy_item
				}
			else
				-- expand area
				local rel_p = vector.subtract(p,pos)
				local rel_minp = vector.subtract(minp_exp,pos)
				local rel_maxp = vector.subtract(maxp_exp,pos)
				local source_minp = vector.subtract(rel_p,radius)
				local source_maxp = vector.add(rel_p,radius)
				local minp_dif = vector.subtract(rel_minp, source_minp)
				local required_radius = minp_dif.x > 0 and minp_dif.x or 0
				required_radius = minp_dif.y > required_radius and minp_dif.y or required_radius
				required_radius = minp_dif.z > required_radius and minp_dif.z or required_radius
				local maxp_dif = vector.subtract(rel_maxp, source_maxp)
				required_radius = maxp_dif.x > required_radius and maxp_dif.x or required_radius
				required_radius = maxp_dif.y > required_radius and maxp_dif.y or required_radius
				required_radius = maxp_dif.z > required_radius and maxp_dif.z or required_radius
				if required_radius > 120 then
					minetest.chat_send_all("aborting, required_radius is: "..required_radius)
				end
				minetest.chat_send_all("required_radius is: "..required_radius)
				minp_exp,maxp_exp,_,data,_,a = cozylights:getVoxelManipData(pos, required_radius)
				--local origin = a:position(i)
				sources[#sources+1] = {
					--pos=pos,
					pos=p,
					cozy_item=cozy_item
				}
				--if #cozylights.single_light_queue > 0 then
				--	local prev_source = cozylights.single_light_queue[#cozylights.single_light_queue]
				--	local radius, _ = cozylights:calc_dims(prev_source.cozy_item)
				--	local possible_area_min = vector.subtract(pos,radius)
				--	local possible_area_max = vector.add(pos,radius)
				--else
					--print("adding "..name.." to single_light_queue")
					--table.insert(cozylights.single_light_queue, {
					--	pos=origin,
					--	cozy_item=cozy_item
					--})
				--end
			end
		end
	end
	--cozylights:setVoxelManipData(vm,data,param2data,true)
	gent_total = gent_total + mf((os.clock() - t) * 1000)
	gent_count = gent_count + 1
	print("Average mapchunk generation time " .. mf(gent_total/gent_count) .. " ms. Sample of: "..gent_count)
	if #sources > 0 then
		cozylights.area_queue[#cozylights.area_queue+1]={
			--minp=vector.subtract(minp,39),
			--maxp=vector.add(maxp,39),
			minp=minp_exp,
			maxp=maxp_exp,
			sources=sources
		}
	end
end)