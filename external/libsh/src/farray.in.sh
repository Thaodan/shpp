## functions for fake_arrays ########################################################################
# fake arrays are array emulated by using : as $IFS
#
#
#####################################################################################################
# NOTE:
# unlike arrays normal arrays the index of arrays starts with 1 instead of 0
# if a fake_array function gets a 0 as index parameter all entrys in the array where selected 
#
# 	for example:
#
#		var=`read_farray fu:bar 0`
#	       +var='fu bar'
#####################################################################################################	

#\\ifdef DEBUG_FARRAY_LESS_OUTPUT 
ifen_disable_option() { # if $1 is enabled disable it
    if set +o | grep -q "set -o $1" ; then
	set +o "$1"
	libsh_enabled_shell_options=$libsh_enabled_shell_options:$1
    fi
}


ifde_enable_option() {  # if $1 is disabled and was enabled before, enable it
    if echo $libsh_enabled_options | grep -q $1 && set +o | grep -q "set +o $1" ; then
	set -o "$1"
	libsh_enabled_shell_options=$( echo $libsh_enabled_shell_options | sed "s/:$1//" )
    fi
}
#\\endif
get_farray_lenght() { # get lenght of fake array
    if [ $# -ge 1 ] ; then 
	old_ifs=$IFS
	IFS=:
	for var in $1 ; do
	    get_farry_lenght_count=$(( $get_farry_lenght_count + 1 ))
	done
	IFS=$old_ifs
	echo  ${get_farry_lenght_count:-0}
	unset get_farry_lenght_count var
    else
	echo 0
    fi
}

read_farray() { # read fake array
    if [ $# = 2 ] ; then
	#\\ifdef DEBUG_FARRAY_LESS_OUTPUT
	ifen_disable_option verbose
	ifen_disable_option xtrace
	#\\endif
	old_ifs=$IFS
	IFS=:
	for var in  $1 ; do
	    _read_farry_count=$(( $_read_farry_count + 1 ))
	    if [ $2 -eq  $_read_farry_count ] || [ $2 -eq 0 ] ; then
		if [ ! -z $var ] ; then
		    echo $var
		fi
	    fi
	done
	IFS=$old_ifs
	#\\ifdef DEBUG_FARRAY_LESS_OUTPUT
	ifde_enable_option verbose
	ifde_enable_option xtrace
	#\\endif
    fi
    unset _read_farry_count  var
}

write_farray() {  # write fake array   
    if [ $# -eq 3 ] ; then
	#\\ifdef DEBUG_FARRAY_LESS_OUTPUT
	ifen_disable_option verbose
	ifen_disable_option xtrace
	#\\endif
	farry_content=$( eval echo \$$1)
	if [ ! -z "$farry_content" ] ; then 
		    if [ $( get_farray_lenght "$farry_content") = $(( $2 - 1 )) ] ; then
			eval $1=$farry_content:$3
		    else
			eval $( echo $1)=$( echo $farry_content | sed "s/$(read_farray $farry_content $2 )/$3/")
		    fi
	elif [ $2 = 1 ] ; then
	    eval $1=$3
	else
	    return 1
	fi
	#\\ifdef DEBUG_FARRAY_LESS_OUTPUT
	ifde_enable_option verbose
	ifde_enable_option xtrace
	#\\endif
    fi
}


