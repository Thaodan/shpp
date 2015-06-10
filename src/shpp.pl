#!/usr/bin/perl
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
# GNU General Public License for mo re details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
# config vars ###
####################################
# version, rev config
#$SHPP_VER = @VER@;
#$SHPP_REV = @GITREV@;
#####################################
# base config

# init defined_vars
our $registed_commands = 'stub';
our $INCLUDE_SPACES    = '.';
our $MACRO_SPACES      = '.';
our $appname           = 'shpp';
use File::Path;
use File::Basename;
no warnings 'experimental';
use Getopt::Long;
Getopt::Long::Configure("bundling");
use feature 'switch';
use Shpp::Bind;
our $LINE;

#use strict 'vars';
#use parent 'Exporter';

#FIXME: clean me

our $verbose_output;
our $WARNING_IS_ERROR;
#####################################################################

### communication ###
sub __plain($$) {
    my $first = shift();
    print("$ALL_OFF$BOLD $first:$ALL_OFF @_");
}

sub __msg($$) {
    my $first = shift();
    print("${GREEN}==>${ALL_OFF}${BOLD} $first:${ALL_OFF} @_\n");
}

sub __msg2($$) {
    my $first = shift();
    print("${BLUE} ->${ALL_OFF}${BOLD} $first:${ALL_OFF} @_\n");
}

sub __warning($$) {
    my $first = shift();
    print( STDERR "$YELLOW==>$ALL_OFF$BOLD $first:$ALL_OFF @_\n" );
}

sub __error($$) {
    my $first = shift();
    print( STDERR "$RED==>$ALL_OFF$BOLD $first:$ALL_OFF @_\n" );
    return 1;
}

=pod

syntax: verbose <msg> [mode]
desc: print msg if verbose if defined
modes:
| mode  | desc                         | 
|-------+------------------------------|
|1      |   don't print new line       |
|2      |   don't print line number    |
|3      |   print everything (default) |

=cut

sub verbose {
    my $msg = shift();
    my $mode = ( shift() or 3 );
    if ( defined $verbose_output ) {
        print( STDERR "$YELLOW==>$ALL_OFF$BOLD $$command{line}:$ALL_OFF" )
          if $mode == 3 or $mode == 1;
        print( STDERR "$msg" );
        print( STDERR "\n" ) if not $mode == 1;
    }
}

sub stub() {
    warn("stub");
}

sub debug($) {
    my $line = shift();
    my $msg  = shift();

    if ($DEBUG) {
        print("L$line: $msg\n");
    }
}
### tools ###
sub file_to_array($) {
    my $file = shift();
    my ( $filestream, $string );
    my @rray;

    open( $filestream, $file ) or die("cant open $file: $!");
    while ( $string = <$filestream> ) {
        push( @rray, $string );
    }
    close($filestream);
    return @rray;
}

sub array_to_file($$) {
    my @rray = @{ shift() };
    my $file = shift();
    my $filestream;

    if ( not defined $file ) {
        $filestream = STDOUT;
    }
    else {
        open( $filestream, '>', $file ) or die("cant open $file: $!");
    }
    foreach my $line (@rray) {
        print $filestream $line;
    }
    close($filestream);
}

our $subs = Shpp::Bind->new();

#sub add_sub($$)
#{
#  my $key = shift();
#  my $self = shift();
#  my $sub = shift();
#
#  $subs{$key} = {
#
#		};
#}

=pod
make our script tree

=cut

sub find_commands($) {
    my $counter = 0;
    my $line_raw;
    my $SCRIPT_FILE = shift();
    my ( @line, @lines );
    my %script;

    # skip shebang and check for macro_mode
    if ( $$SCRIPT_FILE[0] =~ /#\!\/.*/ ) {
        if ( $$SCRIPT_FILE[0] =~ /#\!\/bin\/shpp/ ) {
            $macro_mode = 1;
        }
        shift(@$SCRIPT_FILE);
    }

    for $line_raw (@$SCRIPT_FILE) {
        if ( not $macro_mode and not $line_raw =~ /#\\\\/ ) {
            $lines[$counter] = 666;
        }
        else {
            if ( not $macro_mode ) {
                $line_raw =~ s/^#\\\\//;
            }

            @{ $line[$counter] } = split( /[\s,\t]/, $line_raw );
            $lines[$counter] = {
                line => $counter + 1,
                self => ${ $line[$counter] }[0],
                args => \@{ $line[$counter] },
            };
            shift( @{ $line[$counter] } );    # pop first arg
        }
        $counter++;
    }
    %script = (
        lines         => \@lines,
        removed_stack => 0,
    );
    return %script;
}

sub exec_commands($$) {

    # private stuff
    my $script      = shift();
    my $SCRIPT_FILE = shift();
    my $counter     = 0;         # index
    my @args;                    # parsed arguments
    my ( $arg_counter, $arg );   # need to parse
    my $removed_stack     = $$script{removed_stack};
    my $cur_removed_stack = 0;
    my $cmd_ret;                 # return of command

    # stuff that needs to be exported
    local @start;                # line were if block started
    local @end;
    local $command;              # current command
    local %defines;              # defined vars
    local $line_raw;             #FIXME:  make me readonly at every turn
    local @l_cmd_ret;

    for $line_raw (@$SCRIPT_FILE) {
        if ( $$script{lines}[$counter]{self} == { 'else', 'end' }
            or ( @end == 0 and @start == 0 ) )
        {
            #print($$script{lines}[0]{args}[0]);
            # export command
            $command = $$script{lines}[$counter];

            if ( not $macro_mode and $$script{lines}[$counter] == 666 ) {
                for my $word ( \@{$line_raw} ) {

                    #debug($word);
                    # check if $word is a var
                    if ( $word =~ /@*@/ ) {
                        $word =~ s/[^@,@$]//g;
                        $word = &defined($word);
                    }

                    # check if var is a sub
                    stub();

                    #if ( $word ~~  )
                    #{
                    #	tet;
                    #}
                }
            }
            else {
                #debug("L:$counter:");
                #debug("rsub: $subs{$$command{self}}\n");
                #debug("sub: $$command{self}\n");
                my $cur_cmdr =
                  $subs->get( $$command{self} );  # cürrent raw name of command
                                                  # check if command is in %subs
                if ( not $cur_cmdr ) {
                    error("$$command{self} not found");
                }
                else {
                    # parse args end replace eventual vars
                    my $arg_counter = 0;

                    for my $arg ( @{ $$command{args} } ) {
                        debug("$arg\n");
                        if ( $arg =~ /@*@/ ) {
                            $arg =~ s/[^@,@$]//g;
                            $args[$arg_counter] = &defined($arg);
                        }
                        else {
                            $args[$arg_counter] = $arg;
                        }
                        $arg_counter++;
                    }
                    # check if current command has to many args
                    if ( @args > $$cur_cmdr{args} 
                        and not $$cur_cmdr{args} == 'ALL' )
                    {
			print($$cur_cmdr{args}, "\n");
			print(@args,"","\n");
                        error(
"to many args for $$command{self} (max args: $$cur_cmdr{args})"
                        );
                    }
                    else {
                        verbose("calling $cur_cmdr( @args )");
                        $cmd_ret = &{$$cur_cmdr{self}}(@args);

                        #print $cmd_ret;
                        if ( $cmd_ret != 1 && $cmd_ret != 0 ) {
                            $line_raw = $cmd_ret;
                        }
                        else {
#  if last return was just a return status skipp it and add it for iss(inter sub system)
                            if ( $$command{self} == { 'else', 'if' } )   # fixme
                            {
                                $l_cmd_ret[-1] = $cmd_ret;
                            }
                            undef $line_raw;
                        }
                    }

                }
            }
	    @args = '';
	    
        }
        else {
            # get how many lines we need to cut
            $cur_removed_stack = $start[-1] - $end[-1];
            splice( @$SCRIPT_FILE, $start[-1], $cur_removed_stack );
            shift(@start);
            shift(@end);
        }
        $counter++;
    }

=pod 

if # start

else # end(shift), start

end # end
$cur_removed_stack =  @end - @start ; shift(@start)
( $start[-1] = $$command{line} shift(@end,@start) )if IF == false and if else == true
shift @
undef tet
define teg
ifndef tet (
$start[-1] = $$command{line}
ifdef teg 
( - )
else ( $l_cmd_ret && $start[-1] = $$command{line} )
# stuff
end ( $l_cmd_ret && $end[-1] == $$command{line} )
# stuff
else
(
$end[-1] = $$command{line}
)
#stuff
end

=cut

}

### builtin commands
#!error
sub error($) {
    __error( "L$$command{line}:$$command{self}", "@_" );
    exit 1;
}
$subs->add( 'error', 'error', 1 );

#!warning
sub warning($) {
    __warning( "L$$command{line}:$$command{self}", "@_" );
    if ($WARNING_IS_ERROR) {
        __msg2( '', 'warnings are error set' );
        exit(1);
    }
    return 0;
}
$subs->add( 'warning', 'warning', 1 );

#!msg
sub msg($) {
    __msg( "L$$command{line}:$$command{self}", "@_" );
    return 1;
}
$subs->add( 'msg', 'msg', 1 );

#!rem
sub rem {
    return 1;
}
$subs->add( 'rem', 'rem', 'ALL' );

#!if
sub If {
    my ($expr, $cur_cmdr);    # stuff that called cmd returns;
    my ( $call_brace, $call );    #true if we got a call
    my @s_args;
    for my $arg (@_)              # look if we got cmds
    {
        if (   $arg == "not"
            or $arg == "!"
            or $arg == "or"
            or $arg == "and" )    # skip not or etc
        {
            if ($expr) {
                $expr += "$arg ";
            }
            else {
                $expr = "$arg";
            }
        }
        else {
	    $cur_cmdr = $subs->get($arg);
            if ( $cur_cmdr ) {
                verbose( "ok $arg is a sub", 1 );
                $s_args[@s_args] = $cur_cmdr;
                $call = 1;
                next;
            }
            if ($call) {
                push( @s_args, split( /,/, $arg ) );
                verbose( "calling it: @s_args", 2 );
		$expr += "&{${$s_args[0]}{self}}
( $s_args[1], $s_args[2], $s_args[3] )";
$expr += " ";
            }
            else {
                verbose( "ok $arg is a sub", 1 );
                if ( $arg =~ /.*\(/ and not $arg =~ /\)/ )    # arg () begins
                {
                    $s_args[-1]=~ s/\(//;
                    $call_brace = 1;
                    next;
                }
                if (   $call_brace and $arg =~ /\)/
                    or $call_brace )                          # arg ends or not
                {
                    verbose( "calling it: @s_args", 2 );
                    if ( $arg =~ /\)/ )                       # arg() ends
                    {
                        $s_args[-1]=~s/\)//;
                        $cur_cmdr = $subs->get($s_args[0]);
                        if ( $cur_cmdr ) {
                            $expr += "&{$$cur_cmdr{self}}
                              ( $s_args[1], $s_args[2], $s_args[3] )";
                            $expr += " ";
                        }
                    }
                    $s_args[-1] =~ s/,//g;
                }
            }
        }
    }

    # FIXME: make me save
    if ( not eval($expr) ) {
        $start[@start] = $$command{line};
        return 0;
    }
    return 1;
}
$subs->add( 'if', 'If', 'ALL' );

sub ifdef {
    return If( defined, @_ );
}
$subs->add( 'ifdef', 'ifdef', 'ALL' );

sub ifndef {
    return If( '!', defined, @_ );
}
$subs->add( 'ifndef', 'ifndef', 'ALL' );

sub Else() {
   
    # else token
    if ( $l_cmd_ret == 1 ) {

        # ok if(or any command that starts a new end block) was fine skip it
        $start[-1] = $$command{line};
        return 1;
    }
    else {
        # ok if wasn't fine we end this block
        $end[-1] = $$command{line};
        return 0;
    }
    return 1;
}
$subs->add( 'else', 'Else', 0 );

sub end() {
   print $l_cmd_ret;
   print @end;
    # if was fine we end this
    if ( $l_cmd_ret == 1 ) {
        $end[-1] = $$command{line};
    }
    else {
        # ok skip it we're useless
    }
    return 1;
}
$subs->add( 'end', 'end', 0 );
sub endif()
{
   return end();
}
$subs->add( 'endif', 'endif', 0);

=pod
desc.: load macro file
syntax.: macro $file [OPTIONS]

=cut

sub macro($) {
    my $file = shift();
    do $file or die("cant open file $!");
}
$subs->add( 'macro', 'macro', 1 );

=pod
desc.: define var
syntax: define var = var 
syntax2: define var var

=cut

sub define($$) {
    my @var;

    given ( $_[0] ) {

        # c
        when ( $_ =~ / *=* / ) {
            @var = split( /=/, $_ );
        }

        # cpp style define
        default {
            $var[0] = shift();
            $var[1] = shift();
        }
    }
    $defines{ $var[0] } = $var[1];
    return 1;
}
$subs->add( 'define', 'define', 2 );

sub Defined($) {
    my $var = shift();
    verbose("Testing if '$var' is defined");
    if ( exists $defines{$var} ) {
        return $defines{$var};
    }
    else {
        return '';
    }
}
$subs->add( 'defined', 'Defined', 1 );

=pod
desc.:   include file
syntax:  include file [OPTION]
options: noparse - don't parse

=cut

sub include($) {
    my ( $file, @SCRIPT_FILE );
    my $noparse = 0;
    while ( $#_ != 1 ) {
        given ( $_[0] ) {
            when ('noparse') {

                $noparse = 1;
                shift(@_);
            }
            when ('--') {
                shift(@_);
                break;
            }
        }
    }
    $file = shift();
    verbose("Including $file");
    @SCRIPT_FILE       = file_to_array($file);
    $includes{raw}[-1] = \@SCRIPT_FILE;
    $includes{pos}[-1] = $command{line};
    stub_main( \@SCRIPT_FILE, $includes[-1] ) if not $noparse;
    return 1;
}
$subs->add( 'include', 'include', 1 );

sub include_includes($$) {
    my $includes_raw = shift();
    my @SCRIPT_FILE  = shift();
    my ( $include_raw, $cur_pos );
    my ( $pos_counter, $pos_stack ) = 0;
    for $include_raw ( \$includes{raw} ) {
        $cur_pos = $includes{pos}[$pos_counter];
        splice( @SCRIPT_FILE, ( $cur_pos + $pos_stack ),
            0, $SCRIPT_FILE[ ( $cur_pos + $pos_stack ) ], $include_raw );
        $pos_stack += @$include_raw + 1;
        $pos_counter++;
    }
    return @SCRIPT_FILE;
}

sub stub_main($$) {
    my ( @includes_raw, @includes, @pos );
    local $macro_mode;    # if true commands don't start with #!);

=pod
hash with the raw file, the script and the positions of the includes in the root
=cut

    local %includes = (
        'raw'  => \@includes_raw,
        'self' => \@includes,
        'pos'  => \@pos,
    );

    my $file        = shift();
    my $target_file = shift();
    my @SCRIPT_FILE = file_to_array($file);
    my $IID         = int( rand(100) );
    my %script      = find_commands( \@SCRIPT_FILE );
    exec_commands( \%script, \@SCRIPT_FILE );

    if ( @includes_raw != 0 ) {
        @SCRIPT_FILE = include_includes( \%includes, \@SCRIPT_FILE );
    }

    #$SCRIPT_FILE[0] = 0;
    array_to_file( \@SCRIPT_FILE, $target_file );
}

sub print_help() {
    print <<"HELP";
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
  --keep 				don\'t delete tmp files after running
HELP
}

my $use_color;
my $stdout;
my $stderr;
my $target_name;
my $input_file;
our $DEBUG;
if (
    @ARGV == 0 or not GetOptions(
        'verbose|v'        => \$verbose_output,
        'help|h'           => \&print_help,
        'critical-warning' => \$WARNING_IS_ERROR,
        'D=s'              => \%defines,
        'C|color'          => \$use_color,
        'I=s'              => \@INCLUDE_SPACES,
        'M=s'              => \@MACRO_SPACES,
        'o=s'              => \$target_name,
        'stdout'           => \$stdout,
        'stderr=s'         => \$stderr,
        'debug|d'          => \$DEBUG,

        #   '<>' => \$input_file,
    )
  )
{

    print("no options given call with -h for help\n");
    exit(1);
}

$input_file = shift();

if ($use_color) {
    our $ALL_OFF = "\e[1;0m";
    our $BOLD    = "\e[1;1m";
    our $BLUE    = "${BOLD}\e[1;34m";
    our $GREEN   = "${BOLD}\e[1;32m";
    our $RED     = "${BOLD}\e[1;31m";
    our $YELLOW  = "${BOLD}\e[1;33m";
}

if ($stderr) {
    open( STDERR, $stderr ) or die("Cant open file: $!");
}

if ( $stdout || !$target_name ) {
    undef $target_name;
}

if ($input_file) {
    stub_main( $input_file, $target_name );
}
