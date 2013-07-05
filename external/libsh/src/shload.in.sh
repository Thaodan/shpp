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
    __shl_error_status=1
    case $1 in
      /*)
	    . $1
	__shl_error_status=$?
	;;
      *)
	    LIBSH_shload_old_ifs=$IFS
	    IFS=:
	    for __lib_dir in ${IMPORT_LIBRARY_PATH}:${SH_LIBRARY_PATH}; do
		IFS=$LIBSH_shload_old_ifs
		if [ -e $__lib_dir/$1 ] && [ -f $__lib_dir/$1 ] ; then 
		    . ${__lib_dir}/$1
		    __shl_error_status=$?
		    break
		fi
		IFS=:
	    done
	    IFS=$LIBSH_shload_old_ifs
	    ;;
    esac
    unset  __lib __lib_dir LIBSH_shload_old_ifs
    return $__shl_error_status
}

import() 
# . file with check if already . it
{
    while [ ! $# = 0 ] ; do
	LIBSH_import_old_ifs=$IFS
	IFS=:
	for __lib in $LIBSH_IMPORTED ; do
	    IFS=$LIBSH_import_old_ifs
	    if [ "$__lib" = $1 ] ; then
		__lib_aready_imported=true
		break 
	    fi
	    IFS=:
	done 
	IFS=$LIBSH_import_old_ifs
	if [   -z $__lib_aready_imported  ] ; then
	    if shload $1 ;then
		LIBSH_IMPORTED=$LIBSH_IMPORTED:$1
	    else
		echo "error loading $1"
		return 2
	    fi
	fi
	shift
	unset __lib_aready_imported LIBSH_import_old_ifs
    done  
    return 0 # return how many libs were already imported
}
