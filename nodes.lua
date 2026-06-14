-- All possible light levels
for i = 1, minetest.LIGHT_MAX do
	minetest.register_node("cozylights:light" .. i, {
		description = "Light Source " .. i,
		paramtype = "light",
		light_source = i,
		--tiles ={"invisible.png"},
		drawtype = "airlike",
		walkable = false,
		sunlight_propagates = true,
		is_ground_content = false,
		buildable_to = true,
		pointable = false,
		groups = { dig_immediate = 3, not_in_creative_inventory = 1 },
		floodable = true,
		use_texture_alpha = "clip",
	})
end

-- two separate loops to keep content ids in order
for i = 1, minetest.LIGHT_MAX do
	minetest.register_node("cozylights:light_debug" .. i, {
		description = "Light Source " .. i,
		paramtype = "light",
		light_source = i,
		tiles = { "default_glass.png" },
		drawtype = "glasslike",
		walkable = false,
		sunlight_propagates = true,
		is_ground_content = false,
		buildable_to = false,
		pointable = true,
		groups = { dig_immediate = 3, not_in_creative_inventory = 1 },
		floodable = true,
		use_texture_alpha = "clip",
	})
end

--this hack naively assumes it can trigger a cheaper mapblock mesh update than the engine hack(update_liquids)
--seems to be true in most situations if done right, except not all of them, which maybe makes it useless
--with wield_light it leaves artifacts from time to time so reverted that, will test on node_light next time
minetest.register_node("cozylights:hax", {
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	air_equivalent = true,
})
