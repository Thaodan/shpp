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
# GNU General Public License for more details.
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
our $INCLUDE_SPACES = '.';
our $MACRO_SPACES = '.';
our $appname = 'shpp';
use File::Path;
use File::Basename;
use Getopt::Long;
use feature 'switch';
#use strict 'vars';
#use parent 'Exporter';

#FIXME: clean me
our $ALL_OFF="\e[1;0m";
our $BOLD="\e[1;1m";
our $BLUE="${BOLD}\e[1;34m";
our $GREEN="${BOLD}\e[1;32m";
our $RED="${BOLD}\e[1;31m";
our $YELLOW="${BOLD}\e[1;33m";

our $verbose_output;
our $WARNING_IS_ERROR;
#####################################################################

### communication ###
sub __plain($$)
{
    my $first = shift();
    print("$ALL_OFF$BOLD $first:$ALL_OFF @_");
}

sub __msg($$)
{
    my $first = shift();
    print( "${GREEN}==>${ALL_OFF}${BOLD} $first:${ALL_OFF} @_");
}

sub __msg2($$) {
    my $first = shift();
    print("${BLUE} ->${ALL_OFF}${BOLD} $first:${ALL_OFF} @_");
}

sub __warning($$)
{
    my $first = shift();
    print( STDERR "$YELLOW==>$ALL_OFF$BOLD $first:$ALL_OFF $@");
}

sub __error($$)
{
    my $first = shift();
    print( STDERR "$RED==>$ALL_OFF$BOLD $first:$ALL_OFF @_");
    return 1;
}

sub verbose($)
{	
    if ( defined $verbose_output )
    {		
	print( STDERR "$YELLOW==>$ALL_OFF$BOLD$ALL_OFF @_");
    }
}

sub stub()
{
    warn("stub");
}

### tools ###
sub file_to_array($)
{
    my $file = shift();
    my $filesteam;
    my @rray;

    open($filestream, $file) or die("cant open $file: $!");
    @rray = <$filestream>;
    close($filestream);

    return @rray;
}

sub array_to_file($$) 
{
    my @rray = shift;
    my $file = shift;
    my $filestream;

    open($filestream, $file) or die("cant open $file: $!");
    print($filestream, @rray);
    close($filestream);
}
=pod
make our script tree
=cut
sub find_commands($)
{
    my $counter = 0, $line_raw;
    my @SCRIPT_FILE = shift(), @line;
    my @lines;
    my %script;
	
         
    for $line_raw ( @SCRIPT_FILE )
    {
	if ( not $line_raw =~ /^#\\\\/ )
	{
	    $lines[$counter] = 666;
	}
	else
	{
	    @line = split(/[\s,\t]/, $line_raw); 
	    %{$lines[$counter]} = (
		line => $counter,
		self => \$line[0],
		args => \@line,
	    );
	}
	$counter++;
    }

    %script = (
	lines => \@lines,
	end_else => 0,
	end => 0,
    );
    return %script;
}

sub exec_commands($$) 
{
    # private stuff
    my  %script      = shift();
    my  @SCRIPT_FILE = shift();
    my  $counter=0;
    my  $line_raw;
    my  @args;
    my  $arg_counter, $arg;

    # stuff that needs to be exported
    our $end_else    = $$script{end_else};
    our $end         = $$script{end};
    our %command;    # current command
    our @cut, @cut_end;
 
    for $line_raw ( @SCRIPT_FILE )  
    {
	if ( $end == 0 && $end_else == 0 )
	{
	    if ( ${script{lines}[$counter]} == 666 )
	    {
		stub();
	    }
	    else
	    {
		# export command
		%command = %{$script{lines}[$counter]};
		
		if (not defined( &{$script{lines}[$counter]{self}} ) ) 
		{
		    error("$command{self} not found");   
		}
		else
		{
		    # parse args end replace eventual vars
		    $arg_counter = 0;
		    
		    for $arg ( $script{lines}[$counter]{args} )
		    {
			if ( not $arg_counter == 0 )
			{
			    if ( $arg =~ m/@*@/ )
			    {
				$arg =~ s/[^@,@$]//g;
				$args[$arg_counter]=&defined($arg);
			    }
			    else     
			    {
				$args[$arg_counter]=$arg;
			    }
			    $arg_counter++;
			}
		    }
		    &{$script{lines}[$counter]{self}}( $args[0..-1]); 
		}    
	    }
	}
	else
	{
	    my $to_cut = $cut[-1] - $cut_end[-1]; # get how many lines we need to cut
	    splice(@SCRIPT_FILE, $cut[-1], $to_cut);
	}
    }
}

our %defines;    # defined vars

### builtin commands
#\\error
sub error($)
{
    __error("L$command{line}:$command{self}", "@_");
    exit 1;
}

#\\warning
sub warning($) 
{
    __warning("L$command{line}:$command{self}", "@_");
    if ( $WARNING_IS_ERROR )
    {
	__msg2('', 'warnings are error set');
	exit(1);
    }
}
#\\msg
sub msg($) 
{
    __msg("L$command{line}:$command{self}", "$@");
}

sub if($) 
{
    my $unsuccesfull = 'false';
    $end_else++;
    if ( $unsuccesfull == 'true' )
    {
	$cut[$command{line}] = 1;
    }
}

sub else() 
{
    # remove else or end token and add explizit end token
    $end_else--;
    $end++;
    if ( $cut[-1] || $cut[-1] != 0 )
    {
	$cut_end[$command{line}] = 1;
    }
    else
    {
	$cut[-1] = 0;
	$cut[$command{line}] = 1;
    }
}

sub end()
{
    # look if we need explizit end token
    if ( $end == 0 )
    {
	# we don't, remove some else or end token
	$end_else--;
    }
    else
    {
	# ok we do, remove explizit end token
	$end--;
    }
    $cut_end[$command{line}] = 1;
}
=pod
desc.:   include file
syntax:  include file [OPTION]
options: noparse - don't parse
         
=cut
sub include($)
{
    my $file;
    my @SCRIPT_FILE;
    while ( $#_ != 1 )
    {
       given($_[0])
       {
	   when( 'noparse' )
	   {
	       
	       shift(@_);
	   }
	   when ( '--' )
	   {
	       shift(@_);
	       break;
	   }
       }
    }
    $file        = shift();
    @SCRIPT_FILE = file_to_array($file);
    $includes_raw[$#includes_raw] = \@SCRIPT_FILE;
    stub_main(\@SCRIPT_FILE, $includes[$#includes]);
}

=pod
desc.: define var
syntax: define var = var 
syntax2: define var var
=cut
sub define($$)
{
    my @var;

    given ($_[0])
    {
	# c
	when ( $_ =~ / *=* / )
	{
	    @var = split( /=/, $_ );
	}
	# cpp style define
	default
	{
	    $var[0] = shift();
	    $var[1] = shift();
	}
    }
    $defines{$var[0]} = $var[1];
    
}

sub defined($)
{
    my $var = shift();
    
    if ( $defines{$var} )
    {
	return $defines{$var};
    }
    else
    {
	return '';
    }
}

sub include_includes($)
{
#



}

sub stub_main($$) 
{
    our @includes;
    our @includes_raw;
    my $file            = shift();
    my @SCRIPT_FILE     = file_to_array($file);
    my $IID             = int(rand(100));
    my %script          = find_commands(\@SCRIPT_FILE);
    exec_commands(\%script, \@SCRIPT_FILE);

    include_includes(\@includes_raw);
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

our $target_name;
our $input_file;
our $stdout;
our $stderr;

GetOptions ('verbose' => \$verbose_output,
	    'help|h' => \&print_help,
	    'critical-warning' => \$WARNING_IS_ERROR,
	    'D=s'              => \%defines,
	    'I' => \@INCLUDE_SPACES,
	    'M' => \@MACRO_SPACES, 
	    'o' => \$target_name, 
	    'stdout' => \$stdout,
	    'stderr=s' => \$stderr,
	 #   '<>' => \$input_file,
    );

$input_file = shift();

if ( $stderr )
{
    open(STDERR, $stderr) or die("Cant open file: $!");
}
if ( $stdout || ! $target_name )
{
    $target_name = <STDOUT>;
}
if ( $input_file )
{
    stub_main($input_file, $target_name);
}



	    
	    
	    
