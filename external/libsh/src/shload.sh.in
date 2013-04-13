# base library path for import if  $SH_LIBRARY_PATH is not set
readonly IMPORT_LIBRARY_PATH=/usr/lib:/usr/lib32:/usr/local/lib:$HOME/.local/lib 
 
shload()
#################################################################
# import sh libs that are in $IMPORT_LIBRARY_PATH and $SH_LIBRARY_PATH
# vars:
# IMPORT_LIBRARY_PATH set by  import
# SH_LIBRARY_PATH     set by user use to add a library path
#################################################################    
{
    unset __shl_error_status
    case $1 in
      /*)
	    . $1
	__shl_error_status=$?
	;;
      *)
	    old_ifs=$IFS
	    IFS=:
	    for __lib_dir in ${IMPORT_LIBRARY_PATH}:${SH_LIBRARY_PATH}; do
		old_ifs=$IFS
		if [ -e $__lib_dir/$1 ] && [ -f $__lib_dir/$1 ] ; then 
		    . ${__lib_dir}/$1
		    __shl_error_status=$?
		    break
		fi
		IFS=:
	    done
	    ;;
    esac
    unset  __lib __lib_dir
    return $__shl_error_status
}

import() 
# . file with check if already . it
{
    while [ ! $# = 0 ] ; do
	old_ifs=$IFS
	IFS=:
	for __lib in $LIBSH_IMPORTED ; do
	    IFS=$old_ifs
	    if [ "$__lib" = $1 ] ; then
		__lib_aready_imported=true
		break 
	    fi
	    IFS=:
	done 
	IFS=$old_ifs
	if [   -z $__lib_aready_imported  ] ; then
	    if shload $1 ;then
		LIBSH_IMPORTED=$LIBSH_IMPORTED:$1
	    else
		echo "error loading $1"
		return 2
	    fi
	fi
	shift
	unset __lib_aready_imported
    done  
    return 0 # return how many libs were already imported
}
