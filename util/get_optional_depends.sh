#!/bin/bash

# This script is naive: does not try to find mod.conf recursevily, so it sometimes can miss something,
# and also it can add something unrelated, that is just some logic for light_sources and not a nodedef,
# and probably some ancient mod' file extension won't be picked up if it's a thing, aside from gorillions of
# other problems. Does enough so far

match="light_source"

games_directory="../../../games"
mods_directory="../../"
game_files=$(grep -l -R --include="*.lua" $match $games_directory)
mod_files=$(grep -l -R --include="*.lua" $match $mods_directory)
files=("${game_files[@]}""${mod_files[@]}")
mod_names=""
i=0
for file in $files
do
	directory=$(dirname $file)
	mod_conf=$(find $directory -name "*.conf")
	if [[ $mod_conf != "" ]]; then
		dir_name_comma="$(basename $directory),"
		if [[ $mod_names != *$dir_name_comma* ]]; then
			let i++;
			mod_names="${mod_names} $dir_name_comma"
		fi
	fi
done
echo "mod_names array:" $mod_names
echo "length:" $i