_groups=($1)
_gids=($2)
uname=$3
n=${#_groups[@]}
for ((i=0;i<${#_groups[@]};++i)); do
	group=${_groups[$i]}
	gid=${_gids[$i]}
	addgroup --gid $gid $group
        usermod -a -G $group $uname
done
