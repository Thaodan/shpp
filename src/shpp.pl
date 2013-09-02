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
$registed_commands = 'stub';
$INCLUDE_SPACES = $PWD;
$MACRO_SPACES = '.';
$appname =~s/$ARGV[0]/*\//;
$tmp_dir = TEMPLATE;

use File::Path;
use File::Basename;
use feature 'switch';
use tree;
#####################################################################

### communication ###
sub __plain()
{
    my $first = $_[1];
    shift(@_);
    print("$ALL_OFF$BOLD $first:$ALL_OFF @_");
}

sub __msg()
{
    my $first = $_[1];
    shift(@_);
    print( "${GREEN}==>${ALL_OFF}${BOLD} $first:${ALL_OFF} @_");
}

sub __msg2() {
    my $first = $_[1];
    shift(@_);
    print("${BLUE} ->${ALL_OFF}${BOLD} $first:${ALL_OFF} @_");
}

sub __warning()
{
    my $first = $_[1];
    shift(@_);
    print( STDERR "$YELLOW==>$ALL_OFF$BOLD $first:$ALL_OFF $@");
}

sub __error()
{
    my $first = $_[1];
    shift(@_);
    print( STDERR "$RED==>$ALL_OFF$BOLD $first:$ALL_OFF @_");
    return 1;
}

sub verbose()
{	
    if ( defined $verbose_output )
    {		
	print( STDERR "$YELLOW==>$ALL_OFF$BOLD$ALL_OFF @_");
    }
}

sub new() 
{
    my $obj = shift();
    my $pkg = shift();
    bless($obj, $pkg);
}

=pod
make our script tree
=cut
sub find_commands()
{
    my $_command, %command, $command_no,  $command_raw;
    my $counter = 0, @script;
    $erase_till_endif = 'false';
    $endif_notfound = 'false';
    my $file_raw = $_[1];
    my ( @line, $line_raw );
    open(SCRIPT_FILE, $file_raw);
    if ( ! $file ) 
    {
	die("cant open $file: $!");
    }
    
    while ( defined($line_raw <SCRIPT_FILE> ) )
    {
	if ( $line_raw =~ /^#\\\\/ )
	    $script[$counter] = 666;
	else
	{
	    @line = split(/[\s,\t]/, $line_raw); 
	    %{$script[$counter]} = {
		line => $counter,
		self => \&$line[0],
		args => @line,
	    };
	}
	$counter++;
     }
    close(SCRIPT_FILE);
    return @script;
}

sub exec_commands() 
{
    my @script = \@{$_[0]};
    if ( $script[$counter] == 666 )
    {
	# ok we got non code part
    }
    else
    {
	if (not defined( &{$script[$counter]{self}} ) ) 
	{
	    error("$script[$counter]{self} not found");   
	}
	else
	{
	    &{$script[$counter]{self}}( ${script[$counter]{args}}[1..-1]); 
	}    
    }
}
### builtin commands
#\\error
sub error()
{
    __error("L$command{line}:$command{self}" "@_");
    exit 1;
]

#\\warning
sub warning() 
{
    __warning("L$command{line}:$command{self}" "@_");
    if ( $WARNING_IS_ERROR )
    {
	__msg2('' 'warnings are error set');
	exit(1);
    }
}
#\\msg
sub msg() 
{
    __msg("$L$line_ued" "$@");
}

sub If() 
{


}


sub stub_main() 
{
    my @script = find_commands($_[0]);
    exec_commands(\@script, $_[1]);
}
