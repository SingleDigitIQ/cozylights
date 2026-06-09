local manual_content = [[
<global size=16>
<center><style color=#F5A623 size=20>CozyLights Alpha Reference</style></center>

<style color=#F52023>Warning: This wasn't supposed to be possible in pure Lua and is a proof-of-concept alpha build full of experiments that may not always work as intended and will be subject to breaking changes.
In case you are new to unstable Luanti mods, and want to remove this mod from your world, to avoid inconvenience, you have two options:
1. use unknown_node cleaner mods after cozylights mod is disabled, such as: https://content.luanti.org/packages/AntumDeluge/cleaner/ or https://content.luanti.org/packages/AiTechEye/servercleaner/
</style>
2. second option currently might not work correctly with some mapgens, but just in case run /clearlights in areas where cozylights were generated and only then disable the mod, in case you forgot an area, you can reenable the mod to run /clearlights again

- light_brush is not yet craftable, available only in creative. Only default mode for light_brush is tested, others probably now work incorrectly
- always_fix_edges is on by default now, which is maybe too expensive for potato. Check cozylights mod settings, the ones that are in Luanti settings
- Can still crash with out of memory error if you place too many huge nodes in quick succession, or rebuild them, or mapgen generates too many massive projectors or simply too many light_sources, or if generally your game is incredibly heavy. In that case decrease global radius in /cozysettings and use the brush to manually place something big or make your mapgen less flashy
- This is not recommended for multiplayer just yet
- In case you have adjusted global_radius in /cozysettings or /zs and its now lower than the previous, light clearance for older lights wont work correctly, you will have to /clearlights manually
- There can be small issues with invisible worldedit:placeholder nodes, but with Terraform mod it just works
- Your feedback matters, so dont hesitate to reach out.


<style color=#55FF55 size=18>Commands</style>
<style color=#FF5555>Note:</style> Currently max radius is 120 for the commands below. If your value is invalid it will adjust to the closest valid number or report an error. Eventually, the max radius will be much higher.
<style color=#00FFFF>/clearlights</style> <style color=#AAAAAA>[number]</style>
Removes invisible light nodes in an area with the specified radius. Helpful to remove lights created with the light brush.
<style color=#888888>Example: /clearlights 120</style>
<style color=#00FFFF>/rebuildlights</style> <style color=#AAAAAA>[number]</style>
Rebuilds the light map in the area. Useful in case you changed the settings or accidentally broke some lights by mining in debug. This can be slow if there are lots of light sources with far-reaching light.
<style color=#888888>Example: /rebuildlights 40</style>
<style color=#00FFFF>/fixedges</style> <style color=#AAAAAA>[number]</style>
Fixes obstacles' opposite edges for the light map in the area. Irrelevant if you run the default settings and always_fix_edges is on. When always_fix_edges is off, a heuristic faster algo computes light maps and does so with errors, light often leaks through 1-node-thick diagonal walls or light up opposite edges.
<style color=#00FFFF>/cozydebugon</style> <style color=#AAAAAA>[number]</style>
Makes all cozy light nodes visible and interactable. You can basically build lights just as you would with any other structures before the dedicated tools are available.
<style color=#00FFFF>/cozydebugoff</style> <style color=#AAAAAA>[number]</style>
Makes all cozy light nodes invisible and non-interactable again.
<style color=#00FFFF>/optimizeformobile</style> <style color=#AAAAAA>[number]</style>
Removes all cozy light nodes which do not touch a surface of a visible node (like cobble). The default algorithm spreads light in a sphere and lights up the air, which might cause FPS drops on potato devices/mobile. Good for multiplayer schematics, though it might make some places darker.
<style color=#00FFFF>/spawnlight</style> <style color=#AAAAAA>[brightness] [reach] [dim]</style>
Spawns a light at your position which does not use the user-friendly light brush algorithm, but the raw ambient light algorithm.
<style color=#00FFFF>/daynightratio</style> <style color=#AAAAAA>[ratio float]</style>
Changes the engine day_night_ratio for your player. 0 is the darkest night possible (very moody, helps with building/testing). 1 is the brightest day.
<style color=#00FFFF>/cozyadjust</style> <style color=#AAAAAA>[size] [adjust_by] [keep_map]</style>
Changes the brightness of all cozy light nodes by [adjust_by] in the area of [size]. Can be negative. [keep_map] is 1 by default; if the adjustment pushes a node out of the 1-14 bounds, the command safely reverts to preserve the map. Type 0 for [keep_map] if you are okay with breaking the light map.
<style color=#00FFFF>/uncozymode</style> <style color=#AAAAAA>[number]</style>
Currently broken, do not use, use /clearlights instead. Calls clear lights continuously at all players' positions in the area. Disable it by typing /cozymode or via /cozysettings.
<style color=#55FF55 size=18>Shortcuts</style>
Short versions of commands above:
<style color=#00FFFF>zcl</style>   - clearlights
<style color=#00FFFF>zrl</style>   - rebuildlights
<style color=#00FFFF>zfe</style>   - fixedges
<style color=#00FFFF>zdon</style>  - cozydebugon
<style color=#00FFFF>zdoff</style> - cozydebugoff
<style color=#00FFFF>zofm</style>  - optimizeformobile
<style color=#00FFFF>zsl</style>   - spawnlight
<style color=#00FFFF>zs</style>    - cozysettings
<style color=#00FFFF>zdnr</style>  - daynightratio
<style color=#00FFFF>za</style>    - cozyadjust

More info about how the mod works can be found on contentdb or on the forum.
Light Excavation Tool 9000 TURBO V3, Consumer Grade Reality Bending Device and Shadow Brush are coming soon!
]]

minetest.register_craftitem("cozylights:alpha_manual", {
	description = "CozyLights Alpha Manual",
	inventory_image = "default_paper.png",
	stack_max = 1,
	on_use = function(itemstack, user, pointed_thing)
		if not user or not user:is_player() then
			return
		end
		local formspec = string.format(
			[=[
			formspec_version[6]
			size[9,8]
			hypertext[0.5,0.5;8,7;manual_display;%s]
			button_exit[3.5,7.2;2,0.6;quit;LFG]
		]=],
			minetest.formspec_escape(manual_content)
		)
		minetest.show_formspec(user:get_player_name(), "cozylights:manual_fs", formspec)
	end,
})
