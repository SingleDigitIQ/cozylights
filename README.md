# Cozy Lights

Lights which make everything cozy =^__^=

Early alpha, but at least NotSoWow, Sumi, MisterE, Agura and Sharp have expressed curiosity, that already makes six of us, good enough for release. Feedback, suggestions, bug reports are very welcome. **At this dev stage Cozy Lights can be good for builders in creative mode**, survival is somewhat maybiyish okayish but not really.

Voxel light maps are a complete game changer - it is almost like going from 2d to 3d in terms of depth. You now have 14 shades for every visible building block, and it does not have to register 14 versions of every building block. Cobble only challenge has got a whole lot easier, something fun to look at with the least fun texture is possible now with just this mod :> Disabling smooth lighting might can make for an interesting aesthetic in some cases.

You can also build these lights just like you do with any structures, in other words, place invisible blocks of light of all possible engine light levels block-by-block. Tools are coming soon to make this process more user-friendly, right now you will need to make them visible and interactable in debug mode.

**WARNING:**

**1. after removing Cozy Lights from your world you will be left with spheres of unknown nodes. Easiest could be to reenable the mod and call ```/clearlights``` in all locations Cozy Lights are active.**

**2. if you have override_engine_light_sources enabled, then in case you ever remove Cozy Lights mod from your world, you will be left with broken lights. To fix it, you will need to use the mod fixmap or anything that updates/fixes engine lights. override_engine_light_sources is disabled by default, so it should be safe.**

**3. if a light source in a game/mod is not static, sometimes disappears like a firefly or changes the brightness according to some event or over time, light map in that area will probably look weird.**

**4. on_generated callback is disabled, so if you want a scene with cozy lights in caverealms or everness, you will have to run ```/rebuildlights``` in an area**

**5. wielded cozy light is by default disabled, you can enable it in settings. However, other wielded light mods might cause issues easily in that case as of now. You can enable wielded cozy light in main menu Settings -> Mods -> Cozy Lights**

**6. auto rebuild lights is disabled for now, so you will have to run ```/rebuildlights``` command if you have more than one light sources close to each other and you removed one of them.**

*For what it does it's quite fast, it is supposed to somehow get even faster. I have recently discovered that my CPU is 10(!) years old and it's actually usable on my PC. Would appreciate if somebody with a beast PC would try this mod out and post a couple of benchmarks, and also if some phone poster will try to do the same*

## Supported mods and games

Most of the most popular ones on paper, but its early alpha, so it can still be broken. It's not just popular ones, actually no idea how many it supports, some of them are not even on ContentDB.

If a mod or a game you like is not supported or there are some problems, tell me, I will see what can be done. You can just drop a list of mods you have issues with in review. Eventually cozy lights' support will attempt to balance the overall feel and look of the game with meticulous consideration, but we are not at that stage yet.

## Light Brush

*Click or hold left mouse button* to draw light with given settings. Light Brush' reach is 100 nodes, so you can have perspective. Note: with radiuses over 30 nodes as of now mouse hold won't have an effect.

*On right click* settings menu opens up. The menu has hopefully useful tooltips for each setting. You can set radius, brightness, strength and draw mode. There are 5 draw modes so far: default, blend, override, lighten and darken.

## Chat Commands

Currently max radius is 120 for these commands, and for some it's less than that, if your value is invalid it will adjust to closest valid. Eventually max radius will be much higher. 

```/clearlights <number>``` removes invisible light nodes in area with specified radius. Helpful to remove lights created with light brush. Example usage: ```/clearlights 120```

```/rebuildlights <number>``` rebuilds light map in an area with specified radius. Useful in case you changed the settings or accidentally broke some lights by other commands or by mining in debug. This can be slow if there are lots of light sources in the area with far reaching light. Example usage: ```/rebuildlights 40```

```/fixedges <number>``` fixes obstacles' opposite edges for light map in an area with specified radius. Default algorithm sacrifices accuracy for speed, because of that the lights can still go through diagonal walls if they are only one node thick, and as of now they can sometimes light up an edge(1 block from a corner) of the opposite side of an obstacle. With this command you are supposed to be able to fix it, but currently it's weird, broken. You can use it but the result wont necessarily look good.

```/cozydebugon <number>``` makes all cozy light nodes visible and interactable in an area with a specified radius. With it you can also basically build lights just as you would with any other structures before the tools for that are available.

```/cozydebugoff <number>``` makes all cozy light nodes invisible and non-interactable again in an area with a specified radius.

```/optimizeformobile <number>``` removes all cozy light nodes which do not touch a surface of some visible node, like cobble for example. It is maybe useful, because default algo spreads light in a sphere and lights up the air above the ground too, which might be a bit challenging for potato and mobile to render reliably, they might experience FPS drops. Good if you are building a schematic for a multiplayer server. This option might slightly decrease the quality of light map, example: you have a light node with strength of 7 above the ground, and that ground is visible because of that, but after using this option that light node will be removed, so that part of the ground might be left in complete darkness. Basically might make some places darker.

```/spawnlight <brightness float> <reach_factor float> <dim_factor float>``` spawn a light at your position which does not use user friendly light brush algo, but ambient light algo.

```/cozysettings <brightness float or ~> <reach_factor float or ~> <dim_factor float or ~>``` change global settings for node light sources like torches, meselamps, fireflies, etc. Put ```~``` instead of a float and previous setting for that value will remain unchanged. This change persists after exiting and re-entering the world again.

```/daynightratio <ratio float>``` change Minetest engine day_night_ratio for the player who used the command. ```0``` is the darkest night possible, you can observe how dark it can be on the screenshots, was useful in testing, probably will help with building too. ```1``` is the brightest possible day. Some gradations in between are maybe under appreciated and seem pretty moody, I guess that would depend on a texture pack.

## For Developers

There are like I think 5 algo versions of drawing lights or I refactored that, because I never heard of DRY, never happened. All algos sacrifice accuracy for speed and miss some nodes for huge spheres.

*Plans for API:*

- You will be able to override cozylights' global step, disable it and call it from your global step. Wait, however technically you can do this

- You will be able to override any defaults

- Register unique settings for specific nodes

# todo

- add erase mode for light brush

- chat command shortcuts

- add inventory images for lights and debug lights, make them only available in creative

- make floodable light sources not work in water just like in original wielded light

- add command to increase/decrease brightness of every light node in an area, at least if limited for now

- readd on_generated

- readd light auto rebuild on light source destroy

- see what can be done about dynamic light sources if it will be needed at all after light auto rebuild. dynamic means their brightness is not constant or maybe they disappear/reappear

- make darkness nodes, wielded darkness, Darkness Brush

- add static natural scene(stop the time, fix the sun/moon in one position, update the area accordingly)

- raytracing

- add undo

- add optional more pleasant day/night cycle

- add optional sky textures

- add priveleges so schematics can be used on multiplayer server

- add multiplayer/mobile settings(very little light nodes, very simple light map), and mid settings(more or less okayish), max is default

- move to base "unsafe" methods for tables? seems like luajit optimizes it all away and it's useless to bother?

- try spread work over several loops and try vector.add

- figure out what to do about lights going through diagonal, one node thick walls. also still somehow manage to keep algo cheap

- Optimize memory usage, use several voxel manipulators for biggest lights, will be slower but much more stable, also increase max radius to even more mentally challenged value

- maybe three types of darkness nodes, ones that are completely overridable with cozylights, and ones that arent(make a darker light shade), and ones that completely ignore cozylights

- lights auto rebuild on first load after settings change?

- make a table for existing decoration nodes

- make sure spheres of big sizes dont miss too many blocks

- give light sources metadata, so when nearby light sources are destroyed you can find and rebuild easily, also give metadata to light brush epicenter for the same reason

- maintain files in which you record light source positions, which can be quickly grabbed to rebuild lights if there is a removal

- add cone light blocks, so those lights can be built on top of each other to make static lights from old games

- add light grabber tool, Light Excavation Tool 9000 TURBO V3, so that the light wont be selectable without it

- add Consumer Grade Reality Bending Device to create preset nodes with chosen qualities

- add global step override api, ability to implement cozylights global step into a game/other mod global step more efficiently, maybe add generic global step call like mainloop or mainstep, see what other games do with it, choose or create convention for this i guess

- add handle_async where it makes sense

LICENSE

MIT for my code, will appreciate reasonable attribution

And there is a texture from MTG, which will be eventually replaced:

default_glass.png is by Krock (CC0 1.0)

my debug textures are WTFPL if anything