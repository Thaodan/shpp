#!/bin/sh
# shpp shell script preprocessor
# Copyright (C) 2013  Björn Bidar
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
registed_commands=stub
INCLUDE_SPACES=$PWD
MACRO_SPACES=.
appname=${0##*/}
tmp_dir="$(mktemp -u "${TMPDIR:-/tmp}/${appname}.XXXXXXX")"

################################################################

if [ ${0%/*} = . ] ; then
    shpp="$(which $0 2>/dev/null )" || shpp="${0%/*}/shpp"
else
    shpp="${0%/*}/shpp"
fi

#####################################################################

### communication ###
__plain() {
    local first="$1"
    shift
    echo "${ALL_OFF}${BOLD} $first:${ALL_OFF} "$@""
}

__msg() {
    local first="$1"
    shift
    echo "${GREEN}==>${ALL_OFF}${BOLD} $first:${ALL_OFF} "$@"" 
}

__msg2() {
    first="$1"
    shift
    echo "${BLUE} ->${ALL_OFF}${BOLD} $first:${ALL_OFF} "$@""
}

__warning() {
    local first=$1
    shift
    echo "${YELLOW}==>${ALL_OFF}${BOLD} $first:${ALL_OFF} "$@"" >&2
}

__error() {
    local first=$1
    shift
    echo "${RED}==>${ALL_OFF}${BOLD} $first:${ALL_OFF} "$@"" >&2
    return 1
} 

verbose()
# usage: verbose <msg> [mode]
# desc: print msg if verbose if defined
# modes:
# 0      do none of that (default)
# 1      don't print new line       
# 2      don't print line number    
# 3      do both
{
    if [ $verbose_output ] ; then
        if [ ! "${2:-0}" -eq  2 ] ; then
            printf %s "${YELLOW}==>${ALL_OFF}${BOLD} L${line_ued:-0}: " >&2
        fi
        printf %s "${ALL_OFF}$1" >&2
        if [ ! "${2:-0}" -eq 1  ] && [ ! "${2:-0}" -eq 3 ] ; then
            printf '\n' >&2
        fi
    fi
}

die() {
    verbose 'got signal to die, dieing'
    IID=1 cleanup
    exit ${1:-1}
}

cleanup() {
    if [ ! $keep ] ; then
        local clean_files
        read -r clean_files < "$tmp_dir/$IID/clean_files"
	rm -rf "$clean_files"
    fi
}

var()
# usage: var var[=content]
# description: set var to content if =content is not given, output content of var
#              vars can be put in an other by using / just like when creating dirs
{
    case $1 in 
	*=|*=*) 
	    local __var_part1=$( echo "$1" | sed -e 's/=.*//' -e 's/^[+,-]//' )
            local __var_part2=$( echo "$1" | cut -d '=' -f2- )
	    local __var12="$tmp_dir/$__var_part1"
	    mkdir -p ${__var12%/*}
	    case $1 in 
		*+=*)
		    if [ -d "$tmp_dir/$__var_part1" ] ; then
			printf  -- $__var_part2 > "$tmp_dir/$__var_part1/"\  $(( 
				$( echo "$tmp_dir"/$__var_part2/* \
				    | tail  | xargs basename ) + 1 ))
		    else
			printf -- "$__var_part2" >> "$tmp_dir/$__var_part1"  
		    fi
		    ;;
 		*-=*) false ;;
                *)  printf  -- "$__var_part2" > "$tmp_dir/$__var_part1" ;;
	    esac
	    ;;	
	*) 
	    if [ -d "$tmp_dir/$1" ] ; then
                local dir_content
                for dir_content in "$tmp_dir/$1/"*
                do
                    echo "${dir_content##*/}"
                done
	    elif [ -e "$tmp_dir/$1" ] ; then 
		cat "$tmp_dir/$1"
	    else
		return 1
	    fi
	    ;;
    esac	
}

unvar()
# usage: unvar <var>
# desription: remove var
{
    rm -rf "${tmp_dir:?}/$1"
}

link()
# usage: link <var> <target>
# description: link var to target
{
    local __var12="$tmp_dir/$2"
    mkdir -p "${__var12%/*}"
    ln -s "$tmp_dir/$1" "$tmp_dir/$2"
}

count()
# usage: count <+,-> <number> [<COUNTER>]
# description: charge number from or to file, if COUNTER is not given use existing
{
    COUNTER=$3
    local counter_cur
    read counter_cur <  "$tmp_dir/$COUNTER" || true # exit status isn't relevant
    case $1 in 
	-)  echo $(( $counter_cur - $2 )) > "$tmp_dir/$COUNTER" ;;
	+)  echo $(( $counter_cur + $2 )) > "$tmp_dir/$COUNTER" ;;
    esac
}
alias count--='count - 1'
alias count++='count + 1'

random()
# usage: random [range] [digits]
# description: gen random number
{
    tr -dc ${1:-1-9} < /dev/urandom | head -c${2:-4}
}

cutt()
# usage: cut <range begin >  <range end> <file> [1]
# description:  primitive to remove line from file
#               if $4 is true we output deleted content
# example: cut 1,9 tet
{
    if [  $4 ] ; then
	sed -n "$1,$2p" $3
    fi
    sed -e "$1,$2 d" -i $3
}

cutt_cur()
# usage: cut_cur <range begin> <range end> [t]
# description: just like cut but for current file
{
    # save removed lines (difference between range begin and range end + 1)
    count + $(( $2 - $1  + 1)) \
	  self/command/removed_stack
    cutt $1 $2 "$tmp_dir"/self/pc_file.stage1 $3
}


############################################################

find_commands()
# usage: find_commands <file>
# description: parse <file> and execute parsed commands on <file>
{
    local _command   command command_no  command_raw IFS \
	counter=0 arg_counter=0 arg_string __arg__ arg1 \
	arg2 arg3 arg4 arg5 arg6 arg7 arg8 in_arg_string=false
    local erase_till_endif=false
    local endif_notfound=false
    local unsuccesfull
    var self/command/removed_stack=0
    local if_line
    local IFS='
'
    for find_commands_line in $( grep -hn \#\\\\\\\\$2 "$1"  | sed 's|:.*||' ); do 
	counter=$(( $counter + 1))
	var self/command/lines/$counter="$find_commands_line"
    done
    counter=0 # reset counter after parsing lines
    for _command in $( grep  \#\\\\\\\\$2 "$1" | sed -e 's/#\\\\//'  ) ; do
        unset IFS
	counter=$(( $counter + 1))
	# current line with removed deleted lines
	local line_ued=$( var self/command/lines/$counter )
	# current current lines eg. without deleted lines
	local line=$(($line_ued-$( var self/command/removed_stack))) 
	# remove tabs and spaces after and before string
	_command=$( echo "$_command" | sed -e 's/[ \t]*$//' -e 's/^[ \t]*//' -e  "s|^\ ||" -e 's|\ $||') 
	if [ $erase_till_endif = true ] ; then
	    if [ "$_command" = endif ] || [ "$_command" = else  ]  ; then
		cutt_cur "$if_line" "$line" 
#\\!debug_if  cp "$1" "$tmp_dir/ifsteps/pc_file.stage.$_find_command_count"
		erase_till_endif=false
		[ $_command = else ] && found_if_or_else=true
	    elif [ ! $endif_notfound = false ] ; then
		false
	    fi
	else
	    verbose "Found '$_command' calling corresponding command"
	    case $_command in 
		#if $_command has space clear  it,  give 
		# the commands still the ability to   know who they are
		# and parse it's arguments
		*\ * ) 	        
		    IFS=" "
		    for __arg__ in $_command ; do
			# test if we got/get now arg_string and test our new arg is a string
			if [ $in_arg_string = false  ] && case $__arg__ in
			     # ugly but the only way to test for string start eg ' or " 
			       \'*\'|\"*\") false;;
                               \'*\'*) false ;;
                               \"*\"*) false ;;
                                \'*|\"*) true;;
				 *)false ;; 
			     esac
			then
			     # if true, open our arg_string
			     in_arg_string=true
			     arg_string=$(echo "$__arg__" | sed -e 's|^\"||' -e "s|^\'||")
                        # test if we got string end character or add our __arg__ to arg_string if not
			elif [ $in_arg_string = true  ] ; then
			    case $__arg__ in
				# arg string ends, reset arg_string
				*\"|*\')
				    # only run sed if we have characters before quote end
				    if ! [ $__arg__ = \' ] || [ $__arg__ = \" ] ; then
					__arg__="${arg_string} $(echo "$__arg__" | sed -e 's|\"$||' -e "s|\'$||")"
				    else
					__arg__="$arg_string"
				    fi
				    arg_string=
				    in_arg_string=false;
				    ;;
                                # $arg_string doesn't end add __arg__ to it
				*) arg_string="${arg_string} ${__arg__}" ;;
			    esac
			fi
			# after we parsed arg string set arg<n>
			if [ ! "$arg_string" ] ; then
                            case $__arg__ in
                                @*@)
                                # we got a variable, lets call defined on it
                                __arg__=$(echo "$__arg__"| sed 's|@||g')
                                __arg__=$(defined "$__arg__")
                                ;;
                                \"*\"|\'*\')
                                # strip " or ' from arg at the begin and end
                                __arg__=$(echo "$__arg__" |sed -e  "s|^[\",']||" -e  "s|[\",']$||")
                                ;;
                            esac
                                       
			    case $arg_counter in 
				0)
				    command=$__arg__ 
				    # these commands don't need adiotional args so quit arg parsing
				    case "$command" in 
					!*|rem) break ;;
				    esac
				     ;;
				1) arg1="$__arg__" ;;
				2) arg2="$__arg__";;
				3) arg3="$__arg__";;
				4) arg4="$__arg__";;
				5) arg5="$__arg__";;
				6) arg6="$__arg__";;
				7) arg7="$__arg__";;
				8) arg8="$__arg__";;
				9) break ;;
			    esac	
			    arg_counter=$(( $arg_counter + 1))
			fi
		    done
		    unset IFS
		    arg_counter=0
  		    ;;
		# else $_command is already clear
		*) command=$_command ;;	       		 
	    esac
            IFS=
	    set -- $arg1  $arg2 $arg3 $arg4 $arg5 $arg6 $arg7 $arg8
            unset IFS
	    case "$command" in
		define|macro|include|ifdef|ifndef|error|warning|msg)
 	            $command  "$@"
                    ;;                                            
		'if')           __If       "$@" ;;
		'else')	        __Else                                                        ;;
		'endif')	
		    # just a stub call for syntax error 
		    # cause endif was used before if/ifdef/else
		    endif 
		    ;; 
		'break')          verbose 'Found break abort parsing'; break ;;
		![a-z]*|rem) : ;; # ignore stubs for ignored functions
		*)  if echo "$registed_commands" | grep -q $command ; then
		        $command "$@"
		    else
		        warning "found '$command',bug or unkown command, raw string is '$command_raw'"
		    fi
		    ;;
	    esac
	    arg1=
	    arg2=
	    arg3=
	    arg4=
	    arg5=
	    arg6=
	    arg7=
	    arg8=
        fi
       IFS='
	'
    done
}

### commands ### 
# description:	this are commands that can be executed in $source_file (#\\*)
# 		commands can be builtin or suplied by macro files
# 		most commands exept if* do their write parts after find_commands()
# 		external commands shoud do their write part with a runner
#                that is executed after find_commands()

# usage:  register_external  <__mode> function
# description: this functions  registers  externals to shpp either commands (#\\*) or runners
#
register_external() { 
    local __mode
    case $1 in  # set component to register
	-c|--command) __mode=add_command;;
	-R|--runner)  __mode=add_runner;;
	*) return 1;;
    esac
    shift 
    while [ ! $# = 0 ] ; do
	case $__mode in
	    add_command) registed_commands=$registed_commands:$1 ;;
	    add_runner) registed_runners="$registed_runners $1";;
	esac
	shift
    done
}

# usage: macro file
# description: load macro file must be either relativ to $PWD or to $MACRO_SPACES
macro() {
    local  __cleaned_macro __macro_space __not_found=true
    case $1 in
	\<*\>) 
           __cleaned_macro=$(echo "$1" | \
	       sed -e 's/^<//' -e 's/>$//') ;;
	*) __cleaned_macro=$1;;
    esac
    local IFS=:
    for __macro_space in $MACRO_SPACES ; do
	if [ -e "$__macro_space"/"$__cleaned_macro" ] ; then
	    __cleaned_macro="$__macro_space"/"$__cleaned_macro"
	    __not_found=false
            break
	fi
    done
    unset IFS
    [ $__not_found = true ] && error "'$__cleaned_macro' not found"
    verbose "found macro: '$__cleaned_macro', doing syntax check"
    if sh -n $__cleaned_macro ; then
	. $__cleaned_macro
    else
	error "'$__cleaned_macro' don't passed syntax check, quiting"
    fi  
}

#### built im commands ###
# usage: error msg
# description: display error and die
error() {  
   __error "L$line_ued:error" "$@"
   die 1
}

# usage: warming  msg
# description: display warning
warning() {
    __warning L$line_ued:warning:$command "$@"
    if [ $WARNING_IS_ERROR ] ; then
	__msg2 '' 'warnings are error set, dieing'
	die 2
    fi
}

# usage: msg msg
# description: display mesage
msg() {
    __msg "$L$line_ued" "$@"
}

# usage: if condiion
#            msg bla
#        endif
# description: test for condition and do bla
__If() {
    # set default logig eg. positive
    local __logic_number=1 \
	__condition_done=false \
	__condition
    unsuccesfull=false
  # parse modifers
    local IFS=" "
    while [ ! $__condition_done = true ] ; do
	while [ ! $# = 0 ]; do
	    case $1 in 
		!) __logic_number=0 ;shift ;;
		defined)
                    local result
                    unset IFS
                    shift                    
                    while [ "$1" = "||" ] || [ "$1" = "&&" ] || [ ! $# = 0 ]; do
                        result=$result$(defined "$1")
                        shift
                    done                   
                    case $result in
                        ''|*[!0-9]*) result=${#result} ;;
                    esac
		    __condition="$result >= 1  $__condition"; 
		    IFS=" ";
		    ;;
		\|\|) __break_false=true; shift ;break;;
		\&\&) __break_true=true; shift ;break;;
		*) __condition="$1 $__condition" ; shift;;
	    esac
	done
	if [ $( echo "$__condition" | bc ) = $__logic_number ] ; then
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
		# no chance left that condition can be true, 
		# everything is lost we're unsuccesfull
		unsuccesfull=true 
	    fi
	fi
	__condition_done=true
	found_if_or_else=true
    done
    # check result
    if [ $unsuccesfull = true ] ; then
	verbose "L$line_ued: Condition was not true, remove content till next endif/else, erase_till_endif ist set to true"
	if_line=$line # save $line for find_commands 
	erase_till_endif=true # say find_commands it has to erase fill from $if_line till next found endif
    fi
}

#### if conditions ###
# usage: defined var
# description: test if var is defined return 1 if true return 1 if not 
defined() {
    while [ ! $# = 0 ] ; do
        if [ -e "$tmp_dir/defines/$1" ] ;  then
            if [ -s "$tmp_dir/defines/$1" ] ; then
	        cat "$tmp_dir/defines/$1"
            else
                echo 1
            fi
        else
	    verbose "L$line_ued: $1 was not defined" 
	    echo 0
        fi
        shift
    done
}

#### if conditions ### end

## if aliases ###
ifndef()
# usage: ifndef var
# description: alias to if ! defined var
{
    __If ! defined "$@" 
}

ifdef()
# usage: ifdef var
# description: alias to if defined var
{
    __If defined "$@"
}

# description: see if
endif() { 
    # just a stub that calls error to handle if endif 
    # is before if/ifdef/else
    if [ ! $found_if_or_else ] ; then
        error "Found endif before if, error"
    fi
    unset found_if_or_else
}

__Else()
# description see if
{
    if [ "$unsuccesfull" = false ] ; then
	verbose "L$line_ued:Last if was succesfull,\
removing content from this else till next endif" 
	if_line=$line # save $current_line for find_commands 
	erase_till_endif=true # say find_commands it has to erase fill from 
	                      # $if_line till next found endif
    else
	error "Found else before if, error"
    fi
}

include()
# usage: include [option] file
# usage: include file with option , file must be either relative to $PWD or $INCLUDE_SPACES
# options:
# no_parse: don't parse file
# take: just take file and don't copy it before parsing
{
    
    local  __include_arg  __parser __parser_args __cleaned_include \
	__outputfile__cleaned_include  __include_space \
	current_include_no __not_found=true  


    mkdir -p $tmp_dir/self/include/files
    touch $tmp_dir/self/include/counter
    while [ ! $# = 0 ] ; do
	case $1 in  
	    noparse)  __parser=noparse; shift;;
	    take) __parser=take; shift;;
	    parser=*) 
		# set parser to use another parser than shpp 
		__parser=$( echo $1 | sed 's|parser=||' )
		shift;; 
	    parser_args=*)__parser_args=$( echo $1 | sed 's|parser_args=||' )
		shift;; 
	    *) __cleaned_include=$1; shift;;
	esac
    done
    verbose "L$line_ued: Opened '$__cleaned_include' to parse,\
call a new instance ${parser+of} ${parser}to process file"
    case $__cleaned_include in
	\<*\>) 
           __cleaned_include=$(echo "$__cleaned_include" | \
	       sed -e 's/^<//' -e 's/>$//') ;;
    esac
    # only seek in INCLUDE_SPACES if we got no /*
    case $__cleaned_include in 
	/*)
            if [ -e "$__cleaned_include" ] ; then
                __not_found=false
            fi
        ;;
	*) 
	    local IFS=:
	    for __include_space in $INCLUDE_SPACES ; do
		if [ -e "$__include_space"/"$__cleaned_include" ] ; then
		    __cleaned_include="$__include_space"/"$__cleaned_include"
		    __not_found=false
		    break
		fi
	    done
            unset IFS
	    ;;
    esac
    [ $__not_found = true ] && error "'$__cleaned_include' not found"
    count++ self/include/counter
    current_include_no=$( var self/include/counter )
    __outputfile__cleaned_include=$( echo "$__cleaned_include" | \
	sed -e 's|\/|_|g' -e 's|\.|_|g')
    case ${__parser:-SELF} in  
	shpp)  $shpp   --tmp $tmp_dir/slaves --stdout \
	    "$__cleaned_include"> \
            "$tmp_dir/$IID/include/files/${current_include_no}${__outputfile__cleaned_include}"  || \
	     error "spawned copy of ourself: $appname returned $?, quiting" ;; 
	take)
	    mv "$__cleaned_include" "$tmp_dir/$IID/include/files/${current_include_no}${__outputfile__cleaned_include}"
	    ;;
	noparse)
	    ln -s  "$__cleaned_include" \
	    "$tmp_dir/$IID/include/files/${current_include_no}${__outputfile__cleaned_include}"
	    # no $parser is used
	    ;;
	SELF)
	    stub_main $__cleaned_include $tmp_dir/$IID/include/files/${current_include_no}${__outputfile__cleaned_include} ;;
	*) $__parser $__parser_args ;; # use $parser with $parser_args 
    esac
    # FIXME dirty workaround if we running after find_commands()
    # cause $line is set local in it
    if [ ! $line ] ; then
	var self/include/lines/$current_include_no=$(wc -l < "$tmp_dir"/self/pc_file.stage1)
    else
	var self/include/lines/$current_include_no="$line" 
    fi
}

define()
# usage: define var=content
#    or: define var content
# description: define variable(s)
# note: define supports definig of multiple variables
#       if var=content mode is used $1 is used in definition, than shift
#       if var content mode is used $1 and $1 is used in definition, than shift
{
   while [ ! $# = 0 ] ; do
       # use internal var function with defines as root space
       # NOTE: settings arrays like this curenntly not supported:
       # #\\define FRUITS { BANANA APPEL TOMATO }
       case $1 in
	   *=*) var "defines/${1}"     ;;
           *)   var "defines/${1}=${2}" ; shift;;
       esac
       shift
   done
}

### commands end ### 

### runners ###

write_shortifdefs() { # write #\\! flags to $2
    for var1 in $( var defines )  ; do 
	sed -i  "s/^#\\\\\\\\\!$var1//" "$1"
    done
}

include_includes() { 
    local include_lines \
	include_line   __tmp_include \
	__realy_cleaned_include __include_space \
	include_no=0  include_stack=0
    
    # make backups before do include
    cp "$tmp_dir/self/pc_file.stage2" "$tmp_dir/self/pre_include" 
    for include in "$tmp_dir"/self/include/files/* ; do
	include_no=$(( $include_no + 1 ))
	include_line=$( var self/include/lines/$include_no)
	# discard stack of one
	if [ ! $include_stack = 1 ] ; then
           include_line=$(( $include_stack + $include_line))
	fi
	sed "$include_line,$ d" $1 >  \
	    "$tmp_dir/self/include/cut_source"
	sed "1,$include_line d" $1 > \
	    "$tmp_dir/self/include/cut_source_end"
	cat "$include" >> \
		"$tmp_dir/self/include/cut_source"
	cat "$tmp_dir/self/include/cut_source_end" >> \
		"$tmp_dir/self/include/cut_source"
	cp "$tmp_dir/self/include/cut_source" \
	   "$tmp_dir/self/pc_file.stage2"
        # add included document-1 to stack
	include_stack=$(( $include_stack - 1 +  $( wc -l  \
						   <  "$include" || true)))
    done
}

replace_vars() {
    verbose replace_vars "Opening '$2'"
    local replace_var replace_var_content old_ifs IFS shifted_one
    [ ! -z "$depth" ] && shifted_one=${1#*/}/
    for replace_var in $( var "$1" ) ; do
	# if we got a var that contains other vars run us again
	if [ -d "$tmp_dir/$1/$replace_var" ] ; then
	    local depth=1
	    replace_vars "$1/$replace_var" "$2"
	else
	    replace_var_content=$(var $1/$replace_var)
	    verbose "replacing @${shifted_one}${replace_var}@ with $replace_var_content"
	    sed -ie "s|@${shifted_one}${replace_var}@|$replace_var_content|g" $2|| \
		error "replace_var: sed quit with $?"
	fi
    done 
}

clear_flags() { # cleas #\\ flags in 
    sed -ie '/^#\\\\*/d' "$1"
}

instance_create()
# usage: instance_create 
# description:  create_instance
#               if $IID is not set, set IID from
#               calling random
# example: instance_create
{
    if [ ! $IID ] ; then
        IID=$(random)
    fi
    mkdir -p "$tmp_dir"/$IID
    echo "$tmp_dir/$IID" > "$tmp_dir"/$IID/clean_files 
}

instance_enter()
# usage: instance_enter
# description:  enter_instance
# example: instance_enter
{
    if [  -e "$tmp_dir"/self ] ; then
        # save last instance self
        mv -f "$tmp_dir/self" "$tmp_dir/$IID/.lastself"
    fi
    verbose "Entering instance '$IID'"
    ln -s $IID "$tmp_dir/self"    
}

instance_leave()
# usage: instance_leave
# description:  leave old instance and return to last instance
# example: instance_leave
{
    rm "$tmp_dir"/self
    verbose "Leaving instance '$IID'"
    if [  -L "$tmp_dir"/$IID/.lastself ] ; then
        mv -f  "$tmp_dir"/$IID/.lastself "$tmp_dir"/self
        cleanup
        IID=$(readlink $tmp_dir/self)
        verbose "Returning to instance '$IID'"
    else
        cleanup
    fi
}

### main function ###

stub_main()    {
#\\!debug_if	mkdir -p "$tmp_dir/ifsteps"
    # if we got no $tmp_dir/self we are at main instance, so init it
    if [ ! -e "$tmp_dir"/self ] ; then
	# init InstanceID to use if we can't use $tmp_dir/self
	# if we are the first instance our id is 1
	IID=1	
	#echo "$tmp_dir" > "$tmp_dir"/self/clean_files 
    # else gen rnd var and move old self to new instance and create new self
    else
        IID=$(random)
    fi
    instance_create
    instance_enter
    if [ $IID = 1 ] ; then
        # add our whole $tmp_dir to our clean_files list
        echo "$tmp_dir" > "$tmp_dir"/self/clean_files
    fi
    # make a copy for our self
    cp "$1" "$tmp_dir/self/pc_file.stage1"
    find_commands "$tmp_dir/self/pc_file.stage1"
    write_shortifdefs "$tmp_dir/self/pc_file.stage1"
    cp "$tmp_dir/self/pc_file.stage1" "$tmp_dir/self/pc_file.stage2"
    test -e "$tmp_dir/defines"  && \
	replace_vars "defines"  "$tmp_dir/self/pc_file.stage2"
    # do runners only in main instance
    if [ $IID = 1 ] ; then
	IFS=" "
	for __runner in $registed_runners ; do
	    $__runner
	done
	unset IFS
    fi
    # finaly include our $includes if $includes is not empty
    [ -e  "$tmp_dir/self/include/files"  ] && include_includes "$tmp_dir/self/pc_file.stage2"
    clear_flags "$tmp_dir/self/pc_file.stage2"
    cp "$tmp_dir/self/pc_file.stage2" "$2"
    instance_leave
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
	    --*|*)
		optspec=o:O:Cc:D:I:M:v # b:dp #-: # short options
		optspec_long=output:,option:,config:,color,,legacy,stdout,critical-warning,tmp:,stderr:,keep,debug,verbose,errexit,\*=\* #,binpath:,desktop,prefix # long options
		PROCESSED_OPTSPEC=$( getopt -qo $optspec --long $optspec_long \
		    -n $appname -- "$@" ) || __error error "Wrong option or no parameter for option given!" ||  exit 1 
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
				*=*) eval "$2";;
				# if its no var 
				# (options can be paased as var too) 
				# threat it as option and enable it
				*) eval "$2=true";; 
			    esac
 			    shift 2 
			    ;;
	            	--tmp) tmp_dir="${2}" ; shift 2;;
			--keep) keep=true; shift ;; # keep temp files
			# all warnings are critical
			--critical-warning) WARNING_IS_ERROR=true ; shift ;; 
			-D) define $2; shift 2 ;;
			-I) INCLUDE_SPACES=$2:$INCLUDE_SPACES; shift 2;;
			-M) MACRO_SPACES=$2:$MACRO_SPACES; shift 2;;
			-o|--output) target_name="$2"; shift 2 ;;
			--stdout) target_name="/dev/stdout" ; shift ;;
			 # tells shpp to pass stder to $2
			--stderr) exec 2> $2 ; shift  2;;
			--) shift; break ;;
		    esac
		done
		if [  -t 1 ] || ( [ $FORCE_COLOR ] && \
		    [ ! $FORCE_COLOR = n ] ) ; then
		    # use only colored out if enabled and 
		    # if output goes to the terminal
		    if  [ $USE_COLOR ] && [ ! $USE_COLOR = n ] || \
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
		    readonly target_name=/dev/stdout
		    __warning warning\
			"using '/dev/stdout' as default output"
		fi 
		if [ ! -e "$1" ] ; then
		    __error error "$1 not found" 
		    false
		    shift
		else
		    for signal in TERM HUP QUIT; do
			trap "IID=1 cleanup; exit 1" $signal
		    done
		    unset signal
		    trap "IID=1 cleanup; exit 130" INT
		    stub_main "$1" $target_name
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
