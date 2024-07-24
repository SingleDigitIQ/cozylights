# Cozy Lights

Lights which make everything cozy =^__^=

Early alpha, but at least NotSoWow, Sumi, MisterE, Agura and Sharp have expressed curiosity, that already makes six of us, good enough for release. Feedback, suggestions, bug reports are very welcome. **At this dev stage Cozy Lights can be good for builders in creative mode**, survival is somewhat maybiyish okayish but not really.

Voxel light maps are a complete game changer - it is almost like going from 2d to 3d in terms of depth. You now have 14 shades for every visible building block, and it does not have to register 14 versions of every building block. Cobble only challenge has got a whole lot easier, something fun to look at with the least fun texture is possible now with just this mod :> Disabling smooth lighting might can make for an interesting aesthetic in some cases.

You can also build these lights just like you do with any structures, in other words, place invisible blocks of light of all possible engine light levels block-by-block. Tools are coming soon to make this process more user-friendly, right now you will need to make them visible and interactable in debug mode.

It is eventually supposed to become accurate enough so that if you learn how to draw, you will have an easier time understanding how depth and shadows work and what can be done with them.

Wielded cozy light is by default disabled for now, you can enable it in Minetest main menu Settings -> Mods -> Cozy Lights

**WARNING:**

**1. after removing Cozy Lights from your world you will be left with spheres of unknown nodes. Easiest could be to reenable the mod and call ```/clearlights``` in all locations Cozy Lights are active.**

**2. if you have override_engine_lights enabled, then in case you ever remove Cozy Lights mod from your world, you will be left with broken lights. To fix it, you will need to use the mod fixmap or anything that updates/fixes engine lights. override_engine_lights is disabled by default, so it should be safe.**

**3. worldedit:placeholder nodes can prevent light map from generating correctly and this currenly happens without notice or options provided. There can be other invisible nodes from some mods and games which would interfere with light map.**

*For what it does it's quite fast, it is supposed to somehow get even faster. I have recently discovered that my CPU is 10(!) years old and it's actually usable on my PC. Would appreciate if somebody with a beast PC would try this mod out and post a couple of benchmarks, and also if some phone poster will try to do the same*

## Supported mods and games

Most of the most popular ones on paper, but its early alpha, so it can still be broken. It's not just popular ones, actually no idea how many it supports, some of them are not even on ContentDB.

If a mod or a game you like is not supported or there are some problems, tell me, I will see what can be done. You can just drop a list of mods you have issues with in review. Eventually cozy lights' support will attempt to balance the overall feel and look of the game with meticulous consideration, but we are not at that stage yet.

## Light Brush

*Click or hold left mouse button* to draw light with given settings. Light Brush' reach is 100 nodes, so you can have perspective. Note: with radiuses over 30 nodes as of now mouse hold won't have an effect.

*On right click* settings menu opens up. The menu has hopefully useful tooltips for each setting. You can set radius, brightness, strength and draw mode. There are 6 draw modes so far: default, erase, override, lighten, darken and blend.

## Chat Commands

Currently max radius is 120 for these commands, and for some it's less than that, if your value is invalid it will adjust to closest valid. Eventually max radius will be much higher. 

```/clearlights <number>``` removes invisible light nodes in area with specified radius. Helpful to remove lights created with light brush. Example usage: ```/clearlights 120```

```/rebuildlights <number>``` rebuilds light map in an area with specified radius. Useful in case you changed the settings or accidentally broke some lights by other commands or by mining in debug. This can be slow if there are lots of light sources in the area with far reaching light. Example usage: ```/rebuildlights 40```

```/fixedges <number>``` fixes obstacles' opposite edges for light map in an area with specified radius. Default algorithm sacrifices accuracy for speed, because of that the lights can still go through diagonal walls if they are only one node thick, and as of now they can sometimes light up an edge(1 block from a corner) of the opposite side of an obstacle. With this command you are supposed to be able to fix it, but currently it's weird, broken. You can use it but the result wont necessarily look good.

```/cozydebugon <number>``` makes all cozy light nodes visible and interactable in an area with a specified radius. With it you can also basically build lights just as you would with any other structures before the tools for that are available.

```/cozydebugoff <number>``` makes all cozy light nodes invisible and non-interactable again in an area with a specified radius.

```/optimizeformobile <number>``` removes all cozy light nodes which do not touch a surface of some visible node, like cobble for example. It is maybe useful, because default algo spreads light in a sphere and lights up the air above the ground too, which might be a bit challenging for potato and mobile to render reliably, they might experience FPS drops. Good if you are building a schematic for a multiplayer server. This option might slightly decrease the quality of light map, example: you have a light node with strength of 7 above the ground, and that ground is visible because of that, but after using this option that light node will be removed, so that part of the ground might be left in complete darkness. Basically might make some places darker.

```/spawnlight <brightness float> <reach_factor float> <dim_factor float>``` spawn a light at your position which does not use user friendly light brush algo, but ambient light algo. "float" means it can be with some arbitrary amount of decimals, or simple integer

```/cozysettings``` opens a global settings menu for cozy lights, here you can adjust node light sources like torches, meselamps, fireflies, etc to make it work better with potato or make light reach mad far and stuff. Some settings which you can find in Minetest game settings for the mod are still not present here(like override_engine_lights which makes everything nicer). These changes persist after exiting and re-entering the world again.

```/daynightratio <ratio float>``` change Minetest engine day_night_ratio for the player who used the command. ```0``` is the darkest night possible, you can observe how dark it can be on the screenshots, was useful in testing, probably will help with building too. ```1``` is the brightest possible day. Some gradations in between are maybe under appreciated and seem pretty moody, I guess that would depend on a texture pack.

```/cozyadjust <size number> <adjust_by number> <keep_map number>``` change brightness of all cozy light nodes by adjust_by value in the area of size. Adjust_by can be negative. Keep_map is 1 by default and can be omitted, when it's 1 and adjust_by will result in a value out of bounds of 1-14(engine light levels) even for one node in the area, the command will revert(have no effect at all), so that light map will be preserved. If you are ok with breaking light map, type 0 for keep_map.


Shortcuts for all commands follow a convention to easier memorize them:

```zcl``` - clearlights

```zrl``` - rebuildlights

```zfe``` - fixedges

```zdon``` - cozydebugon

```zdoff``` - cozydebugoff

```zofm``` - optimizeformobile

```zsl``` - spawnlight

```zs``` - cozysettings

```zdnr``` - daynightratio

```za``` - cozyadjust

## For Developers

There are like I think 5 algo versions of drawing lights or I refactored that, because I never heard of DRY, never happened. All algos sacrifice accuracy for speed and miss some nodes for huge spheres.

*Plans for API:*

- You will be able to override cozylights' global step, disable it and call it from your global step

- You will be able to override any default settings

- Register unique settings for specific nodes

## Todo

- fix a bug that creates light around an attempt of placing a node, instead of actually placed node

- stress test it with heavily modded worlds, possible problem: luajit ram limit for default luajit on linux?

- illuminate transparent liquids too, except dont make floodable light sources work underwater just like in original wielded light

- parse minetest forum for optional_depends

- add inventory images for lights and debug lights, make them only available in creative

- make darkness nodes, wielded darkness, Darkness Brush

- add static natural scene(stop the time, fix the sun/moon in one position, update the area accordingly)

- raytracing

- allow people to run cpu and memory-friendly minimal schematic support version, for multiplayer servers for example

- if certain treshold of light source commonality in an area is reached, those light sources should be ignored

- would it be possible without too much work to programatically determine global commonality of a node from mapgen? example: all water was made to be a light_source of 1 by a game/mod

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

- ci for optional_depends auto update according to content db mods/games updates and releases

### Some expensive notes stackoverflow will never tell about LuaJIT to you or to future me. Summing up my discord rambling because COVID made me forget some of Lua I tried before, so I am writing it down for now.

TLDR: LuaJIT is certainly impressive in some parts, however I would rather refrain from using it for absolutely anything that implies even a bit of performance, unless there is no way to avoid it. It's too slow, and when you try to squeeze anything out of it, it loses most of it appeal/narrative, it even loses purpose. If still too many words, remember just this about Lua: never try to optimize Lua too much, it's never worth it, and, just let Lua iterate. Hating on LuaJIT is based and normalpilled, it's just faster Python.

1. While being smol, it still fails to outperform another state of the art JIT - JS V8. Given that JS V8 is big tech kind state of the art, which means there is certainly at the very least a significant room for improvement. Advantage of Lua in comparison to V8: less RAM consuption for small programs, so it's reasonable to run a bit of LuaJIT on weak hardware, like phones, watches, some smart-whatever, robots. It's not the worst choice.

2. Readability syntax sugar is a meme, I am here to code, not to shitpost, I prefer completely different state of mind from that, something very different, like curly braces and what not.

3. Lua bytecode, same way as Python, keeps function and variable names uncompressed. You could argue but hey that means we can at least restore the original file almost one-to-one from bytecode? Who needs that really, when RAM efficiency is 25%(!) better after using a minifier, and if you use minifier, you abandon debugging and readability(just like in Python, which is a meme language too, and it's typical very readable one letter long variable names). This is how as codebase grows, Lua loses it's only advantage over V8. Hence technically peak Lua is a joke.

3. Peak performance Lua cant be, without a lot of effort, transpiled and rewritten into peak performance compiled language, since it's behavior and optimization techniques are drastically different and by that I mean next level drastically different. Therefore it's not as good for prototyping as JS V8, unless you denounce the very idea of optimizing Lua as heresy.

4. LuaJIT does so much behind your back, so that performance becomes exhaustingly unpredictable. Stuff that works in nearly any other language does not work here, and you will often have to rely on profiler no matter how good you are with Lua, rather than act according to assumptions based on fundamentals. You could even say that what you have to do when Lua performance is concerned, is literal trial and error. You then find a sweet spot and never touch that part of the code again, because it's impossible to reason with/reliably reproduce/improve upon.

5. While you could cope that CPU just does not have enough cache and all, clearly, LuaJIT is best at optimizing *simple* loops. Branches, hash look ups, math? Try your best to decrease the amount for all of those in a loop. It appears that Lua would rather iterate uselessly over and over again the same entries, than have a branch to cut amount of iterations/operations in general. Optimization tip is basically this: try to break down a complicated loop into several simpler loops. LuaJIT is ridiculously fast with simple loops.

6. It appears that most popular object positioned most efficiently in memory. I am not entirely certain how exactly does that happen, because I didn't study LuaJIT source since it's underwhelming performance in anything remotely complicated leaves me feeling powerless, so it's not fun. A hack could be a loop that interacts with an object on startup, if you call/interact with the object enough times it will be slightly faster. It is noticeable in massively expensive loops.

7. If you know you are guaranteeed to have an object consume more RAM during runtime, you may want to preallocate if the codebase is complicated and the codebase is complex enough. Well, at least this behavior can be fully expected based on fundamentals.

8. Refrain from having too many hash look-ups, it's not slow by itself, but apparently it clogs cache fast, so sometimes adding just one hash look-up can result in a massive drop in performance. Surprisingly, refrain from having too much of one of the most simplest parts of LuaJIT - math, best is to pull numbers out of Lua' ass, like in Cozy Lights. Luckily predictably this time, branches are the worst in a loop, however this time they are bad even if they cut a massive amount of operations. So you have to balance here, peak performance Lua demands abandoning DRY completely, but that also means you have consume more RAM. Ideal Lua loop is when it does nothing at all, just iterates. Just let Lua iterate.

9. You can obviously somewhat control cache with local variables, but there is a catch, it only gives somewhat coherent performance results if the loop is very simple.

10. LuaJIT can crash during trying to allocate too much memory in one go as if it's in the earliest dev stage and not ready for prod. JS V8 maybe leaks, but at least does not crash just like that.

## LICENSE

MIT for my code, will appreciate reasonable attribution

And there is a texture from MTG, which will be eventually replaced:

default_glass.png is by Krock (CC0 1.0)

my debug textures are WTFPL if anything