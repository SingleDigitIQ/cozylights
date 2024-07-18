# Cozy Lights

Lights which make everything cozy =^__^=

Early alpha and wasn't supposed to be released in this state, but at least NotSoWow, Sumi, MisterE, Agura and Sharp have expressed curiosity, that already makes six of us. Feedback, suggestions, bug reports are very welcome. **At this dev stage Cozy Lights can be good for builders in creative mode**, survival is somewhat okayish. Also schematics with cozy lights can be used on a multiplayer server just fine. But using cozy lights functionality on a multiplayer server other than prebuilt schematics is not currently recommended, I am working on it. 

Oh yeah, things to know about current alpha state:

- Light Brush on mouse hold is now disabled, only clicking works, because I reworked an algo somehow related to it.

- on_generated callback is disabled, so if you want a scene with cozy lights in caverealms or everness, you will have to run ```/rebuildlights``` in an area

- other wielded light mods might cause issues easily, I will fix it

*For what it does it's quite fast, it is supposed to somehow get even faster. I have recently discovered that my CPU is actually 10(!) years old and it's actually usable on my PC. I would really appreciate if somebody with a beast PC would try this mod out and post a couple of benchmarks, and also if some phone poster will try to do the same*

Supported mods and games: all of the most popular ones on paper, but actually no idea, I used a script to gather optional_depends. Should support quite a variety, some of them are not even on ContentDB. There is a problem with Everness, something really weird happens with vines there, need to investigate

If a mod or a game you like is not supported or there are some problems, tell me, I will see what can be done. You can just drop a list in review, no problem. Eventually cozy lights' support will attempt to balance the overall feel and look of the game with meticulous consideration, but we are not at that stage yet.

**WARNING:**

**1. if you have override_engine_light_sources enabled, then in case you ever remove Cozy Lights mod from your world, you will be left with broken lights. To fix it, you will need to use the mod fixmap or anything that updates/fixes engine lights. override_engine_light_sources is disabled by default, so it should be safe.**

**2. after removing Cozy Lights from your world you will be left with spheres of unknown nodes. Easiest could be to reenable the mod and call ```/clearlights``` in all locations Cozy Lights are active.**

**3. if a light source in a game/mod is not static, sometimes disappears or changes the brightness according to whatever, cozy lights won't behave as intended.**

**4. Alpha version means that it probably does not behave as intended in general.**

Voxel light maps are a complete game changer - if you are an artist or a builder you will notice that it is almost like going from 2d to 3d in terms of depth. You now have 14 shades for every building block, and it does not have to register 14 versions of every building block. Cobble only challenge has got a whole lot easier, something fun to look at with the least fun texture is possible now with just this mod :>

You can also build these lights just like you do with any structures, in other words, place invisible blocks of light of all possible engine light levels block-by-block. Tools are coming soon to make this process more user-friendly, right now you will need to make them visible and interactable in debug mode.

Wielded cozy light behaves exactly as you would expect, just brighter far reaching light source, more cpu work.

Typical node light sources like torches and mese lamps behave almost as you would expect, you place them - they emit light, just brighter and far more reaching. However, I have auto rebuild lights disabled, so at this stage you will have to run ```/rebuildlights``` command if you have more than one light sources close to each other and you removed one of them. I just need to figure out fast enough algo, so running commands after such a trivial action won't be needed soon.

## light brush

Light brush however is a bit different as of now, you cant just remove it entirely yet by destroying a light source block, you will have to remove it by using chat command/commands.

If you want a custom cozy light it's best to use light brush with user-friendly settings. I would rather not recommend playing with global light source settings, unless you really feel committed to the idea of voxel based light maps and are ready to spend lots of time on handling edge cases(when some dim lights stop emitting any lights at all and some bright lights become ridiculously bright) and tuning performance(if you have a ton of lights in the area and you are on mobile - RIP, compile more RAM). Settings like low, mid, high are coming though.

## Chat Commands

Currently max radius is 120 for these commands, and for some it's less than that. It wont be a massive issue to increase this radius as development progresses. Some of these commands are not sufficiently optimized, because I was again trying various versions of the algo, and Lua is not C++, therefore if you are running a potato, think twice before using huge radiuses for some of these commands. Better increase radius gradually to make sure your hardware can handle it with ease. 

```/clearlights <number>``` removes invisible light nodes in area with specified radius. Helpful to remove lights created with light brush. Example usage: ```/clearlights 120```

```/rebuildlights <number>``` rebuilds light map in an area with specified radius. In case you changed the settings or accidentally broke some lights by other commands or by mining in debug. This can be slow if there are lots of light sources in the area with far reaching light. Example usage: ```/rebuildlights 40```

```/fixedges <number>``` fixes edges light map in an area with specified radius. Default algorithm is sacrificing accuracy for speed, because of that the lights can still go through diagonal walls if they are only one node thick, and as of now they can sometimes light up an edge(1 block from a corner) of the opposite side of an obstacle. With this command you can fix it, however, the algoritm is being also changed frequently, i like changed it many times in one day before first release. As of now in alpha it can cut a bit too many lights(as in light can suddenly stop going through a small hole in the wall after this command is used, or through a door, or wont go into a small tunnel while it clearly should). This is a priority, so it might change fast

```/cozydebugon <number>``` makes all cozy light nodes visible and interactable in an area with a specified radius. With it you can basically build lights just as you would with any other structures. Voxel based lighting is limited by it's resolution, therefore some artifacts are possible in complicated cases, and in this mode you can fix the schematic.

```/cozydebugoff <number>``` makes all cozy light nodes invisible and non-interactable again in an area with a specified radius.

```/optimizeformobile <number>``` removes all cozy light nodes which do not touch a surface of some visible node, like cobble for example. It is maybe useful, because default algo spreads light in a sphere and lights up the air above the ground too, which might be a bit challenging for potato and mobile to render reliably, they might experience FPS drops. In case for example if you are building a schematic for a multiplayer server to make it more attractive, you may want to seriously consider this option.
Important note however: this option might slightly decrease the quality of light map, as in when before using this option you have cozy light node with strength of 7 above the ground that is in the dark it will light up that dark ground even if a bit, but after using this option that light node will be removed, so that part of the ground might be left in complete darkness. TLDR: might make some places darker. Another way to help potatos with rendering cozy lights could be disabling smooth lighting in Minetest settings, which in turn might also make appearance of the light map surprising and maybe interesting depending on the scene.

```/spawnlight <brightness float> <reach_factor float> <dim_factor float>``` spawn a light at your position which does not use user friendly light brush algo, but ambient light algo.

```/cozysettings <brightness float or ~> <reach_factor float or ~> <dim_factor float or ~>``` change global settings for node light sources like torches, meselamps, fireflies, etc. This command is useful to faster find the sweet spot you are looking for without the need to exit the world and open the settings. If you put ```~``` instead of a float then previous setting for that value will remain unchanged. This change persists after exiting and re-entering the world again.

```/daynightratio <ratio float>``` change Minetest engine day_night_ratio for the player who used the command. ```0``` is the darkest night possible, you can observe how dark it can be on the screenshots, was useful in testing, probably will help with building too. ```1``` is the brightest possible day. Some gradations in between are maybe under appreciated and seem pretty moody, I guess that would depend on a texture pack.

There are also settings with comprehensive description you can find in Minetest settings -> cozylights 

## For Developers

There are like I think 5 algo versions of drawing lights or I refactored that, because I never heard of DRY, never happened. All algos are not perfectly accurate and miss some nodes for huge spheres.

First is in node_light.lua this one draws light maps for node light sources like torches and lamps, radius and strength depend on node properties.

Second one is in wield_light.lua and is like the first one, but much cheaper and less accurate, it is being used for cozy wielded lights.

Third version is in brush_light.lua to draw light maps for light brush stroke/click, this algo is different from other versions because it works with a formula that takes arguments that are easy to reason with and therefore easy to change and memorize, like you can set exact radius you need even if it does not make sense and stuff.

And there are 2 versions of first and second algo, one is simple, and the other is more expensive, 
the expensive one is supposed to fix some voxel resolution artifacts of the light map and is optional, and currently yet again broken, better not use it unless your lights go through diagonal walls.

*Plans for API: You will soon be able to completely override global step of cozylights(disable it and call it from your global step), and its items(for example balance them if you see gameplay value in this, change textures and what not), and override any defaults, and register specific settings for specific nodes*

Would really appreciate if you won't forget to give credit.

# todo

- readd on_generated

- readd mouse hold for light brush

- raytracing

- add undo

- add optional more pleasant day/night cycle

- add optional sky textures

- add auto light rebuild on light source destroy

- add multiplayer/mobile settings(very little light nodes, very simple light map), and mid settings(more or less okayish), max is default

- optimize light auto rebuild, resolve issue with proper area size so it does not overflow somehow

- move to base "unsafe" methods for tables? seems like luajeet optimizes it all away and it's useless to bother?

- try spread work over several loops and try vector.add

- add priveleges so schematics can be used on multiplayer server

- add override/blend/default modes for light brush

- make darkness nodes, wielded darkness, Darkness Brush

- figure out what to do about lights going through diagonal, one node thick walls. also still somehow manage to keep algo cheap

- Optimize memory usage, use several voxel manipulators for biggest lights, will be slower but much more stable

- maybe three types of darkness nodes, ones that are completely overridable with cozylights, and ones that arent(make a darker light shade), and ones that
completely ignore cozylights

- make automatic light propagation for any decoration light sources on generation and on first load

- make a table for existing decoration nodes

- make floodable light sources not work in water just like in original wielded light

- make sure spheres of big sizes dont miss too many blocks

- optimization skips for big lights

- give light sources metadata, so when they are destroyed you can rebuild easily, except maybe give it to big lights

- maintain files in which you record light source positions, which can be quickly grabbed to rebuild lights if there is a removal

- add cone light blocks, so those lights can be built on top of each other to make static lights from old games

- add light grabber tool, so that the light wont be selectable without it

- then add light controller which will adjust light nodes accordingly and set node_metadata for it, so that if the source is removed everything else also goes dark

- allow Consumer Grade Reality Bending Device to create preset nodes with chosen qualities

- Light Excavation Tool 9000 TURBO V3

- refrain from frying multiplayer servers

- add global step override api, ability to implement cozylights global step into a game/other mod global step more efficiently, maybe add generic global step call like mainloop or mainstep, see what other games do with it, choose or create convention for this i guess

- after algos are perfected, add handle_async where it makes sense

- add static natural scene(stop the time, fix the sun/moon in one position, update the area accordingly)