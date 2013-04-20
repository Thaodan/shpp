#!/bin/sh
# shpp shell script preprocessor
# Copyright (C) 2012  Björn Bidar
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# config vars ### 
####################################
# version, rev config
SHPP_VER=@VER@
SHPP_REV=@GITREV@
#####################################
# base config 

# init defined_vars
defined_vars=all
defined_all=true
registed_commands=stub
INCLUDE_SPACES=.
MACRO_SPACES=.
appname=$( basename $0 )
tmp_dir=$PWD/${appname}tmp  

################################################################

if [ $( dirname $0 ) = . ] ; then
    shpp=$(which $0 2>/dev/null ) || shpp=$( dirname $0 )/shpp
else
    shpp=$( dirname $0 )/shpp
fi


stub() {
    echo stub
}

#####################################################################

# tools.sh.in


### communication ###
plain() {
    local first="$1"
    shift
    echo "${ALL_OFF}${BOLD} $first:${ALL_OFF} "$@""
}

msg() {
    local first="$1"
    shift
    echo "${GREEN}==>${ALL_OFF}${BOLD} $first:${ALL_OFF} "$@"" 
}

msg2() {
    first="$1"
    shift
    echo "${BLUE} ->${ALL_OFF}${BOLD} $first:${ALL_OFF} "$@""
}

warning_msg() {
    local first="$1"
    shift
    echo "${YELLOW}==>${ALL_OFF}${BOLD} $first:${ALL_OFF} "$@"" >&2
}

error_msg() {
    local first="$1"
    shift
    echo "${RED}==>${ALL_OFF}${BOLD} $first:${ALL_OFF} "$@"" >&2
    return 1
} 

verbose() {
    if [ $verbose_output ] ; then
	warning_msg $@
    fi
}


call_handler() {
    case $1 in
	error*) error_msg "$@"; die=1 ;;
	warning*) test "$WARNING_IS_ERROR" = true && die=1; warning_msg "$@";; 
    esac
    if [ $die ]  ; then
	verbose 'got signal to die, dieing'
	IID=1 cleanup
	exit ${assumed_err_status:-13}
    fi
}


# tools.sh.in end 

##################################


cleanup() {
    if [ ! $keep ] ; then 
	rm -rf `cat $tmp_dir/$IID/clean_files`; 
    fi
}


var() {
    case $1 in 
	*=|*=*) 
	    __var_part1=$( echo "$1" | sed -e 's/=.*//' -e 's/[+,-]//' )
	    __var_part2=$( echo "$1" | sed -e 's/.*.=//' )
	    mkdir -p $(dirname $tmp_dir/$__var_part1)
	    case $1 in 
		*+=*)
		    if [ -d $tmp_dir/$__var_part1 ] ; then
			printf  $__var_part2 > $tmp_dir/$__var_part1/\  $(( 
				$( echo $tmp_dir/$__var_part2/* \
				    | tail  | basename )\ + 1 ))
		    else
			printf  "$__var_part2" >> $tmp_dir/$__var_part1  
		    fi
		    ;;
 		*-=*) false ;;
                *)  printf  "$__var_part2" > $tmp_dir/$__var_part1 ;;
	    esac
	    ;;	
	*) 
	    if [ -d $tmp_dir/$1 ] ; then
		ls $tmp_dir/$1
	    elif [ -e $tmp_dir/$1 ] ; then 
		cat $tmp_dir/$1
	    else
		return 1
	    fi
	    ;;
    esac	
}

unvar() {
    rm -rf $tmp_dir/$1
}

count() {
    COUNTER=$3
    case $1 in 
	-)  echo $(( $( cat $tmp_dir/$COUNTER ) - $2 )) > $tmp_dir/$COUNTER ;;
	+)  echo $(( $( cat $tmp_dir/$COUNTER ) + $2 )) > $tmp_dir/$COUNTER ;;
    esac
}
alias count--='count - 1'
alias count++='count + 1'

############################################################


###  alias commands ### 
# this are commands that are only provided as alias, as workaround these alias are before commands 
# (alias must be known before use, instead before call unlike functions)

#\\ifdef 
alias ifdef='If defined'
#\\ifndef
alias ifndef='If ! defined' 


find_commands() {
    local _command   command command_no  command_raw
    erase_till_endif=false
    endif_notfound=false 
    var self/command/removed_stack=0
    var self/command/counter=0
    old_ifs=
    IFS='
'
    for find_commands_line in $( grep -hn \#\\\\\\\\$2 "$1"  | sed 's|:.*||' ); do 
	IFS=
	count++ self/command/counter
	var self/command/lines/$(var self/command/counter)=$find_commands_line
	IFS='
'
    done
    var self/command/counter=0 # reset counter after parsing lines
    IFS='
'
    for _command in $( grep  \#\\\\\\\\$2 "$1" | sed -e 's/#\\\\//'  ) ; do
	IFS=
	count++  self/command/counter
	command_no=$( var self/command/counter )
	# current line with removeing deleted lines
	local line_ued=$( var self/command/lines/$command_no )
	local line=$(($line_ued-$( var self/command/removed_stack))) 
	_command=$( echo "$_command" | sed -e 's/[ \t]*$//' -e 's/^[ \t]*//' )
	if [ $erase_till_endif = true ] ; then
	    if [ $_command = endif ] || [ $_command = else ]  ; then
		sed -ie "$if_line,$line d" "$1" 
#\\!debug_if  cp "$1" "$tmp_dir/ifsteps/pc_file.stage.$_find_command_count"
		erase_till_endif=false
	        # save removed lines (difference between $current_line and $if_line + 1)
		count + $(( $line - $if_line  + 1)) \
		    self/command/removed_stack
		[ $_command = else ] && found_if_or_else=true
	    elif [ ! $endif_notfound = false ] ; then
		false
	    fi
	else
	    verbose "L$line_ued:Found  $_command calling corresponding command"
            # if command wants the raw $_command it can use it
	    command_raw="$_command"
            # we clear $0 from $_command now, the commands don't need to do it
	    case $_command in 
		#if $_command has space, clear  it and give 
		# the commands still the ability to   know who they are
		*\ * ) 	        
		    command=$( echo $_command | \
			sed -e "s| .*||" -e  "s|^\ ||" -e 's|\ $||') 
		    _command=$( echo $_command | \
			sed -e "s|$command ||" -e  "s|^\ ||")
  		    ;;
		# else $_command is already clear
		*) command=$_command ;;	       		 
	    esac					      			
	    case "$command" in
		define) 	define $_command  ;;
		include) 	include $_command ;;
		macro)          macro $_command   ;;
		ifdef)	        ifdef "$_command" ;;
		ifndef)        ifndef "$_command" ;;
		if)            If $_command       ;;
		else)	       Else               ;;
		endif)	
		    # just a stub call for syntax error 
		    # cause endif was used before if/ifdef#
		    endif 
		    ;; 
		break)  verbose 'found break abort parsing'; break ;;
		error)	        error "$_command"           ;;
		warning)	warning "$_command" ;;
		![a-z]*|rem) : ;; # ignore stubs for ignored functions
		*)  if echo $registed_commands | grep -q $command ; then
		        $command $_command
		    else
		        call_handler warning:unkown \
			    "found '$command',bug or unkown command, raw string is '$command_raw'"
		    fi
		    ;;
	    esac
        fi
       IFS='
	'
    done
    IFS=$old_ifs
}


### commands ### 
# description:	this are commands that can be executed in $source_file (#\\*)
# 		commands can be builtin or suplied by macro files
# 		most commands exept if* do their write parts after find_commands()
# 		external commands shoud do their write part with a runner that is executed after find_commands()

register_external() { 
# usage:  register externa
# usage:  register externals in macro files
# description: this command (#\\macro) register externals to shpp either commands (#\\*) or runners
  local __mode
  case $1 in  # set component to register
    -c|--command) __mode=add_command;;
    -R|--runner)  __mode=add_runner;;
    *) return 1;;
  esac
  shift 
  while [ ! $# = 0 ] ; do
    case $__mode in
      add_command) registed_commands=$register_commands:$1 ;;
      add_runner) registed_runners="$registed_runners $1";;
    esac
    shift
  done
}


#\\macro
macro() {
    local  __cleaned_macro __macro_space __not_found=false
    verbose "found macro: $1, doing syntax check"
    case $1 in
	\<*\>) 
            __cleaned_macro=$(echo "$1" | sed -e 's/^<//' -e 's/>$//')
	    old_ifs=$IFS
	    IFS=:
	    for __macro_space in $MACRO_SPACES ; do
		IFS=$old_ifs
		if [ -e "$__macro_space"/"$__cleaned_macro" ] ; then
		    __cleaned_macro="$__macro_space"/"$__cleaned_macro"
		else
		   __not_found=true
		fi
		IFS=:
	    done 
	    ;;
	*) if [ ! -e $1 ] ; then
	    __not_found=true
	    fi
	    __cleaned_macro=$1
	    ;;
    esac
    [ $__not_found = true ] && call_handler error:file \
	"L$line_ued:$__cleaned_macro not found"
    if sh -n $__cleaned_macro ; then
	. $__cleaned_macro
    else
	call_handler error:syntax "$cleaned_macro don't passed syntax check, quiting"
    fi  
}

#### built im commands ###

#!\\if
If() {
    # set default logig eg. positive
    local __logic_number=1 \
	__condition_done=false \
	__condition
    unsuccesfull=false
  # parse modifers
    old_ifs=$IFS
    IFS=" "
    while [ ! $__condition_done = true ] ; do
	while [ ! $# = 0 ]; do
	    case $1 in 
		!) __logic_number=0 ;shift ;;
		defined) 
		    IFS=$old_ifs;  __condition="$(defined $2) $__condition"; 
		    IFS=" ";shift 2
		    ;;
		\|\|) __break_false=true; shift ;break;;
		\&\&) __break_true=true; shift ;break;;
		*) __condition="$1 $__condition" ; shift;;
	    esac
	done
	if [ ` echo "$__condition" | bc ` = $__logic_number ] ; then
	  # if condition was true and we found && (and) go and parse the rest of condition
	    if [ $__break_true ] ; then 
		unset __condition
		continue
	    fi
	else
	    # same for || (or)
	    if [ $__break_false ] ; then
		unset __condition
		continue 
	    else
		unsuccesfull=true # no chance left that condition can be true, everything is lost we're unsuccesfull
	    fi
	fi
	__condition_done=true
	found_if_or_else=true
    done
    # check result
    if [ $unsuccesfull = true ] ; then
	verbose "L$line_ued:Condition was not true, remove content till next endif/else, erase_till_endif ist set to true"
	if_line=$line # save $line for find_commands 
	erase_till_endif=true # say find_commands it has to erase fill from $if_line till next found endif
    fi
}



#### if conditions ###
defined() {
    if [ -e $tmp_dir/defines/$1 ] ;  then
	echo 1
    else
	verbose "L$line_ued:$1 was not defined" 
	echo 0
    fi
}

#### if conditions ### end

#\\endif
endif() { 
    # just a stub that calls call_handler with error to handle if endif is before if/ifdef
    if [ ! $found_if_or_else ] ; then
	call_handler  error:syntax "L$line_ued:Found endif before if, error"
    fi
    unset found_if_or_else
}

#\\else
Else() {
    if [ "$unsuccesfull" = false ] ; then
	verbose "L$line_ued:Last if was succesfull,\
                removing content from this else till next endif" 
	if_line=$line # save $current_line for find_commands 
	erase_till_endif=true # say find_commands it has to erase fill from 
	                      # $if_line till next found endif
    else
	call_handler  error:syntax "L$line_ued:Found else before if, error"
    fi
}

#\\include
include() {
    local  __include_arg  __parser __parser_args __cleaned_include \
	__outputfile__cleaned_include  __realy_cleaned_include \
	__include_space current_include_no

    verbose "L$line_ued:Opened $1 to parse,\
            call ourself to process file" 
    touch $tmp_dir/self/include/counter

    for __include_arg in $@ ; do
	case $__include_arg in  
	    noparse)  __parser=noparse;;
	    parser=*) 
		# set parser to use another parser than shpp 
		__parser=$( echo $1 | sed 's|parser=||' )
		;; 
	    parser_args=*)__parser_args=$( echo $1 | sed 's|parser_args=||' );; 
	    *) __cleaned_include="$__include_arg" ;;
	esac
    done
    case $__cleaned_include in
	\<*\>) 
           __realy_cleaned_include=$(echo "$__cleaned_include" | \
	       sed -e 's/^<//' -e 's/>$//')
	   old_ifs=$IFS
	   IFS=:
	   for __include_space in $INCLUDE_SPACES ; do
               IFS=$old_ifs
	       if [ -e "$__include_space"/"$__realy_cleaned_include" ] ; then
		   __cleaned_include="$__include_space"/"$__realy_cleaned_include"
	       else
		   false
	       fi
	       IFS=:
	   done || \
	   call_handler error:file "L$line_ued:$command:\
                                   $__cleaned_include not found"
	   ;;
    esac
    count++ self/include/counter
    current_include_no=$( var self/include/counter )
    __outputfile__cleaned_include=$( echo $__cleaned_include | \
	sed -e 's|\/|_|g' -e 's|\.|_|g')
    case ${__parser:-SELF} in  
	shpp)  $shpp   --tmp $tmp_dir/slaves --stdout \
	    --stderr=$tmp_dir/logs/errors$__outputfile__cleaned_include.log \
	    "$__cleaned_include"> \
	    $tmp_dir/$IID/include/files/\ 
	    ${current_include_no}${__outputfile__cleaned_include}  || \ 
	    call_handler error:exit_stat \
		"spawned copy of ourself: $appname returned $?, quiting" ;; 
	noparse)  ln -s  $__cleaned_include \
	    $tmp_dir/$IID/include/files/\ 
	    ${current_include_no}${__outputfile__cleaned_include} 
	    # no $parser is used
	    ;;
	SELF)
	    stub_main $__cleaned_include $tmp_dir/$IID/include/files/${current_include_no}${__outputfile__cleaned_include} ;;
	*) $__parser $__parser_args ;; # use $parser with $parser_args 
    esac
    var  self/include/lines/$current_include_no="$line" 
   
  
# for us and run argument of #\\include with us and copy to temp file/stdout
# copy content before #\\include to new file
# copy include argument to new file
# copy content past #\\include to new file 
}

#\\define
define() {
    # use internal var function with defines as root space
    # NOTE: settings arrays like this curenntly not supported:
    # #\\define FRUITS { BANANA APPEL TOMATO }
    var defines/${1}
}

#\\error
error() {  
    call_handler error:called "L$line_ued:$1"
}

#\\warning
warning() {
    call_handler warning "L$line_ued:$1"
}
### commands end ### 

### runners ###

write_shortifdefs() { # write #\\! flags to $2
    old_ifs=$IFS
    IFS='
'
    for var1 in $( var defines )  ; do 
	IFS=$old_ifs
	sed -i "s/"^#\\\\\\\\\!$var1"//" $1
	IFS='
'
    done
}


include_includes() { 
    local include_lines __include include_argument \
	current_include_line   __tmp_include \
	__realy_cleaned_include __include_space 
    # make backups before do include
    cp "$tmp_dir/self/pc_file.stage2" "$tmp_dir/self/pre_include" 
    var self/include/counter=1
    var self/include/stack=0
    current_include_no=$( var self/include/counter)
    for current_include in $tmp_dir/self/include/files/* ; do
	for __include_argument in $__include ; do
	    case $__include_argument in 
		# stub arguments that are only used by #\\include
	        include|noparse|parser=*|parser_args=*) : ;; 
		*) __include=$__include_argument ;;
	    esac
	done
	current_include_stack=$( var self/include/stack )
	current_include_no=$( var self/include/counter)
	current_include_line=$(( $current_include_stack + $( var self/include/lines/$current_include_no )))
	case $current_include in
	    \<*\>) 
                __realy_cleaned_include=$(echo "$current_include" | \
		    sed -e 's/^<//' -e 's/>$//')
		old_ifs=$IFS
                IFS=:
		for __include_space in $INCLUDE_SPACES ; do
		    IFS=$old_ifs
		    if [ -e "$__include_space"/"$__realy_cleaned_include" ] 
		    then
			current_include="$__include_space"/"$__realy_cleaned_include"
		    else
			false
		    fi
		    IFS=:
		done 
		old_ifs=$IFS
	   ;;
	esac
	current_include=$( echo $current_include | xargs basename | sed -e 's|\/|_|g' -e 's|\.|_|g')
	sed "$current_include_line,$ d" $1 >  \
	    "$tmp_dir/self/include/cut_source"
	sed "1,$current_include_line d" $1 > \
	    "$tmp_dir/self/include/cut_source_end"
	cat "$tmp_dir/self/include/files/$current_include" >> \
		"$tmp_dir/self/include/cut_source"
	cat "$tmp_dir/self/include/cut_source_end" >> \
		"$tmp_dir/self/include/cut_source"
	cp "$tmp_dir/self/include/cut_source" \
	    "$tmp_dir/self/pc_file.stage2"
	
	count++ self/include/counter
	count + $(( 1 + $( wc -l < $tmp_dir/self/include/files/$current_include ))) self/include/stack
	IFS='
	'
    done
}

replace_vars() {
    verbose replace_vars "Opening $2"
    local replace_var replace_var_content
    old_ifs=$IFS
    IFS='
'
    for replace_var in $( var  defines ) ; do
	old_ifs=$IFS
	replace_var_content=$(var defines/$replace_var)
	verbose "replacing @$replace_var@ with $replace_var_content"
	sed -ie "s|@$replace_var@|$replace_var_content|g" $2|| \
	   call_handler error:exit_stat "replace_var: sed quit with $?"
	IFS='
'
    done 
}

clear_flags() { # cleas #\\ flags in 
    sed -ie '/^#\\\\*/d' $1
}



### main function ###

stub_main()    {
#\\!debug_if	mkdir -p "$tmp_dir/ifsteps"
    # if we are the first instance our id is 1
    if [ ! -e $tmp_dir/self ] ; then
	# init InstanceID if we can't use $tmp_dir/self
	IID=1
	mkdir -p "$tmp_dir/1"
	ln -s 1 "$tmp_dir/self"
	echo "$tmp_dir" > $tmp_dir/self/clean_files 
    # else gen rnd var and move old self to new instance and create new self
    else
	# same here: init InstanceID
	IID=`tr -dc 1-9 < /dev/urandom | head -c5`
        mkdir -p "$tmp_dir/$IID"
	mv "$tmp_dir/self" "$tmp_dir/$IID/.lastself"
	ln -s $IID $tmp_dir/self
    fi
    verbose "Entering instance $IID"
    mkdir -p "$tmp_dir/self/include/files"
    mkdir -p "$tmp_dir/self/logs"

    # make a copy for our self
    cp "$1" "$tmp_dir/self/pc_file.stage1"
    find_commands "$tmp_dir/self/pc_file.stage1"
    write_shortifdefs "$tmp_dir/self/pc_file.stage1"
    cp "$tmp_dir/self/pc_file.stage1" "$tmp_dir/self/pc_file.stage2"
    test -e $tmp_dir/defines  && \
	replace_vars "defines"  "$tmp_dir/self/pc_file.stage2"
    # do runners only in main instance
    if [ $( readlink $tmp_dir/self )  = 1 ] ; then
	for __runner in $registed_runners ; do
	    $__runner
	done
    fi
    # finaly include our $includes if $includes is not empty
    test  ! -z "$(  ls "$tmp_dir/self/include/files" )" && include_includes "$tmp_dir/self/pc_file.stage2"
    clear_flags "$tmp_dir/self/pc_file.stage2"
    if [ $2 = stdout ] ; then
	cat "$tmp_dir/self/pc_file.stage2"
    else
	cp "$tmp_dir/self/pc_file.stage2" "$2"
    fi
    if  [ ! $IID = 1 ] ; then 
	echo "$tmp_dir/$IID" > $tmp_dir/self/clean_files 
	rm $tmp_dir/self
	mv -f  $tmp_dir/$IID/.lastself $tmp_dir/self
	cleanup
	IID=`readlink $tmp_dir/self` # re init id from last instance
    else
	cleanup
    fi
    
}

    


print_help() {
cat <<HELP
$appname usage: 
      $appname [Options] File
    
  Options:  
  --help	-H -h			print this help
  --version	-V			print version
  --color	-C			enable colored output
  --verbose     -v                      tell us what we do
		
  --output	  -o	<file>		places output in file
  --option	  -O	<option>	give $appname <option>
  --stdout				output result goes to stdout
  --stderr=<destination>                stderr goes to destination
  --critical-warning    		warnings are threated as errors
                   -D<var=var>          define var
                                        ( same as '#\\define var=var') 
                   -I<path>             add path so search for includes
                   -M<path>             same just for macros
  --tmp=<tmp_dir>			set temp directory
  --keep 				don't delete tmp files after running
HELP
}


if [ ! $# = 0 ] ; then 
    while [ ! $# = 0 ] ; do
	case $1 in 
	    --help|-H|-h)	print_help ; shift ;; 
	    --revision) 	echo $SHPP_REV ; shift ;;
	    -V|--version)	echo $SHPP_VER:$SHPP_REV  ; shift ;;
            #   #-*)		echo `read_farray "$err_input_messages" 1`;;
	    --*|*)
		optspec=o:O:Cc:D:I:M:v # b:dp #-: # short options
		optspec_long=output:,option:,config:,color,,legacy,stdout,critical-warning,tmp:,stderr:,keep,debug,verbose,errexit,\*=\* #,binpath:,desktop,prefix # long options
		PROCESSED_OPTSPEC=$( getopt -qo $optspec --long $optspec_long \
		    -n $appname -- "$@" ) || error_msg input "Wrong or to less  input given!" ||  exit 1 
		eval set -- "$PROCESSED_OPTSPEC"; 
		while [ !  $#  =  1  ]  ; do
		    case $1 in 
			# config stuff
			--debug)
			    set -o verbose
			    set -o xtrace
			    shift
			    ;;
			--verbose|-v) verbose_output=true ; shift  ;;
			--errexit) set -o errexit ; shift ;;
			-C|--color) USE_COLOR=true ; shift 1 ;;
			-c|--config) . "$2"  ;shift 2;;
			-O|--option) # pass options to shpp or enable options
			    case $2 in 
				# self explained
				*=*) eval $2;;
				# if its no var 
				# (options can be paased as var too) 
				# threat it as option and enable it
				*) eval $2=true;; 
			    esac
 			    shift 2 
			    ;;
	            	--tmp) tmp_dir=${2} ; shift 2;;
			--keep) keep=true; shift ;; # keep temp files
			# all warnings are critical
			--critical-warning) WARNING_IS_ERROR=true ; shift ;; 
			-D) var defines/$2; shift 2 ;;
			-I) INCLUDE_SPACES=$2:$INCLUDE_SPACES; shift 2;;
			-M) MACRO_SPACES=$2:$MACRO_SPACES; shift 2;;
			-o|--output) target_name="$2"; shift 2 ;;
			--stdout) target_name="stdout" ; shift ;;
			 # tells shpp to pass stder to $2
			--stderr) exec 2> $2 ; shift  2;;
			--) shift; break ;;
		    esac
		done
		if [  -t 1 ] || ( [ $FORCE_COLOR ] && \
		    [ ! $FORCE_COLOR = n ] ) ; then
		    # use only colored out if enabled and 
		    # if output goes to the terminal
		    if  [ $USE_COLOR ] && [ ! $USE_COLOR = [Nn] ] || \
			( [ $FORCE_COLOR ] && [ ! $FORCE_COLOR = n ]  ) ; then 
			
 			if tput setaf 0 > /dev/null 2>&1 ; then
			    ALL_OFF="$(tput sgr0)"
			    BOLD="$(tput bold)"
			    BLUE="${BOLD}$(tput setaf 4)"
			    GREEN="${BOLD}$(tput setaf 2)"
			    RED="${BOLD}$(tput setaf 1)"
			    YELLOW="${BOLD}$(tput setaf 3)"
			else
			    ALL_OFF="\e[1;0m"
			    BOLD="\e[1;1m"
			    BLUE="${BOLD}\e[1;34m"
			    GREEN="${BOLD}\e[1;32m"
			    RED="${BOLD}\e[1;31m"
			    YELLOW="${BOLD}\e[1;33m"
			fi
			
		    fi
		fi
     		if [ -z "$target_name" ] ; then
		    readonly target_name=stdout
		    warning_msg warning "using /dev/stdout as default output"
		fi 
		if [ ! -e "$1" ] ; then
		    error_msg error  "$source_file not found" 
		    false
		    shift
		else
		    stub_main $1 $target_name
		    shift
		fi
		;;
	esac 
    done
else
    echo "No input given enter $appname -h for help"
    false
fi
exit $?
