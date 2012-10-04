#!/usr/bin/perl

#############################################
# given a manpage name, read the raw .troff markup and attempt to convert it
# into wiki markup on stdout...
#
# This script is released under the terms of the GNU GPL.
#
# remember that troff can define new commands, so we can't get everything right
# John McPherson
#
# print helpful debugging messages to stderr?
my $debug=1;
#############################################
my $version="20050311.01";

use strict;

sub print_usage {
    $0 =~ m@([^/]+)$@;
    my $scriptname=$1;
    print "groff-to-wiki version $version\n\n";
    print "usage: $1 [section] manpagename\n";
    print "examples:\n\t$1 open\n\t$1 2 kill\n";
    exit 1;

}

if (@ARGV != 1 && @ARGV != 2) {print_usage()}
if ($ARGV[0] =~ /^--/) {print_usage()}

my $manpagename=pop @ARGV;
my $mansection=pop @ARGV;

if (!$mansection) {$mansection="*"}

my $manpagefilename;

# search the manpath
my $manpath=$ENV{'MANPATH'};
if (!$manpath) {
    if ($debug) {print STDERR "Using default MANPATH\n"};
    $manpath="/usr/share/man:/usr/X11R6/man:/usr/local/man:/usr/man";
}
foreach my $mandir (split(":", $manpath)) {
# try the section as given...
    my $inputglob="$mandir/man$mansection/$manpagename.*";

    if ($debug) {print STDERR "looking for $inputglob\n"}

    my @filenames=glob ($inputglob);
    if (! @filenames) {
	# try stripping the section
	$mansection =~ m/^(\d)/;
	my $strippedmansection = $1;
	if ($strippedmansection) {
	    $inputglob="/usr/share/man/man$strippedmansection/$manpagename*";
	    @filenames=glob ($inputglob);
	}
    }

    if (@filenames) {
	# use the first found man page that matches
	$manpagefilename=shift (@filenames);
	if ($debug) {print STDERR "using $manpagefilename\n"}
	last;
    }
}

# use the first found man page that matches
if (!$manpagefilename) {
    print STDERR "couldn't find any man pages matching $manpagename\n";
    exit 1;
}

if ($manpagefilename =~ /\.gz$/) {
    open (INPUT, "zcat $manpagefilename |") || die "zcat pipe failed: $!";
} else {
    open (INPUT, $manpagefilename) || die "open failed: $!";
}

# variables
my $output="";      # this builds up the entire markup for output
my $indent="";      # prefix for indentation level
my $boldline=0;     # are lines in bold?
my $italicline=0;   # are lines in italic?
my $no_fill=0;      # is the text flowed, or <pre> ?
my $indent_label=0; # used for ;label: paragraph
my $line;
while ($line=<INPUT>) {
    chomp ($line);
    my $filled_text=0; # is 1 for outputting lines as-is

    if ($line =~ m@^\.\\\"@) {next} # troff comment

    if ($line =~ m@^\.Dd@) { # nroff?
	print STDERR ".Dd tag found. This seems to imply an nroff-formatted " .
	"man page rather than\ntroff. Can't currently handle that. Sorry.\n";
	exit 1;
    }

    if ($line =~ m@^\s*$@) {$line=".P"} # blank line => end of paragraph

### check for commands to do with groff variables
    if ($line =~ m@^\.ds@) { # define a string... ignore for now
	# example: .ds UX \s-1UNIX\s0\u\s-3tm\s0\d
	# then referenced as "The \*(UX Operating System"
	# we *could* add this to a lookup table
	next;
    } elsif ($line =~ m@^\.de@) { # define macro... ignore macros for now
	# we *could* add this to a lookup table
	if ($debug) {print STDERR "can't define macro in $line\n"}
	while (<INPUT> !~ /^\.\./) {} # .. = end macro
	next;
    } elsif ($line =~ m@^\.nr@) { # store a number into a number register
	# we *could* add this to a lookup table
	# used for counters? we completely ignore these...
	# Example ".nr a 4" stores 4 into var $a, "\na" references this...
	next;
    } elsif ($line =~ s@^\.so\s+@@) { # include another man page here
	if ($debug) {print STDERR "Warning - ignoring request to include $line"
			 . " manpage\n";}
	next;
    } elsif ($line =~ m@^\.ig@) { # ignore a block of input
	while (<INPUT> !~ /^\.\./) {} # .. = end ignore
	next;
    }
    
    if ($line =~ m@^\.\w+\s+$@) { # strip trailing whitespace
	$line =~ s@\s+$@@;
    }

    # for wiki - must do this before changing '' for italics
    # `` and '' -> "
    $line =~ s@([^\`])\`\`@$1\"@g;
    $line =~ s@([^\'])\'\'@$1\"@g;


### inline font settings
    if ($line =~ m@\\f@) {
	$filled_text=1;
	my $localbold=0;
	my $localitalic=0;
	while ($line =~ m@\\f(\w)@) {
	    my $type=$1;
	    if ($type eq "I") { # italic
		$localitalic=1;
		$line =~ s@\\fI@''@;
	    } elsif ($type eq "B") { # bold
		$localbold=1;
		$line =~ s@\\fB@__@;
	    } elsif ($type eq "R" || $type eq "P") { # roman or previous?
		my $toroman="";
		if ($localitalic == 1) {
		    $toroman="''";
		    $localitalic=0;
		}
		if ($localbold == 1) {
		    $toroman .= "__";
		    $localbold=0;
		}
		$line =~ s@\\f$type@$toroman@;
	    } else {
		print STDERR "unknown font code \\f$type\n";
		$line =~ s@\\f$type@@;
	    }
	} # end of while loop
    }

### headings
     if ($line =~ m@^\.TH@) { # title
	$line = ""; # ignore
    } elsif ($line =~ s@^\.SH\s+@@) { # section heading
	$line =~ s/^\"//; $line =~ s/\"$//; # remove quotes if > 1 word
	$line="\n\n!!$line\n";
	$no_fill=0; # reset?
    } elsif ($line =~ s@^\.SS\s+@\n\n!@) { # sub heading
	$line .= "\n";
	$no_fill=0; # reset?
### line formatting
    } elsif ($line =~ /^\.ce/) { # centre, with optional line count
	$line = "\n";
    } elsif ($line eq ".br") { # linebreak
	$line = "\n";
    } elsif ($line =~ /^\.sp(\s+\d+)?/) { # vertical space eg .sp or .sp 4
	$line = "\n\n";
    } elsif ($line eq ".bp") { # break page
	$line = "\n\n";
    } elsif ($line =~ /^\.[LP]?P/) { # P,LP,PP end paragraph/line break
	if ($indent) {$line="\n"} else {$line = "\n\n"}
    } elsif ($line eq ".nf") { # no-fill mode
	$output .= "\n";
	$no_fill=1;
	next;
    } elsif ($line eq ".fi") { # fill mode (default)
	$line = "\n";
	$no_fill=0;
### indent
    } elsif ($line =~ /^\.RS/) { # RS increment indent
	$line = "\n";
	$indent .= " "; # add a space
    } elsif ($line =~ /^\.RE/) { # RE decrement indent
	$line = "\n";
	$indent =~ s/^.//; # remove a space
    } elsif ($line =~ /^\.TP/) { # indent paragraph with label
	$no_fill=0; # this is a guess - revert back to fill?!
	$output .= "\n";
	$indent=""; # cancel any indent-by spaces, wiki doesn't like that.
	$indent_label=2;
	next;
    } elsif ($line =~ /^\.IP/) { # indent paragraph
	$no_fill=0; # this is a guess - revert back to fill?!
	$output .= "\n";
	if ($line =~ s/^\.IP\s*//) { # given an optional indent text
	    # the first argument is the indentation text, second is spacing
	    $line =~ m@\"([^\"]+)\"@ || $line =~ m@(\S+)@;
	    $output .= ";$1: ";
	} else {$output .= ";: "}
	$indent=""; # cancel any indent-by spaces, wiki doesn't like that.
	next;
    } elsif ($line =~ s@^\.in\s*@@) {
	# add a number to the indentation level... eg .in -4
	# .in by itself goes to the previous indent before the last .in
	if ($line =~ m@(\-?\d+)@) {
	    my $addition=$1;
	    if ($addition >= 0) {
		$indent .= " " x $addition;
	    } else { # negative - remove from indent
		$addition=abs($addition);
		$indent =~ s/.{$addition}//; # remove that many chars
	    }
	}
	next;
    } elsif ($line =~ m@^\.ta@i) { # tab stop positions - ignore
	next;
### Font settings
    } elsif ($line =~ s@^\.B\s+(\"?)@__@) { # bold text
	if ($1 eq '"') {$line =~ s/\"$//} # remove "... " for grouping
	$line .= "__ ";
    } elsif ($line =~ m/^\.B\s*$/) {
	my $nextline=<INPUT>;
	chomp $nextline;
	$line="__${nextline}__\n";
    } elsif ($line =~ s@^\.I\s+(\"?)@''@) { # italic text
	if ($1 eq '"') {$line =~ s/\"$//} # remove "... " for grouping
	$line .= "'' ";
# alternating font styles
    } elsif ($line =~ s@^\.(BR|BI|RB|RI|IB|IR)\s*@@) {
	my ($oddstyle,$evenstyle)=split('', $1);
	my $style;
	foreach $style ($oddstyle, $evenstyle) {
	    if ($style eq "B") {$style="__"}
	    elsif ($style eq "I") {$style="''"}
	    elsif ($style eq "R") {$style=""} # Roman... do nothing
	}
	# arguments are space separated, except when surrounded by "... ..."
	my @arguments=(	$line =~ m@(\"[^\"]+\"|\S+)@g );
	$line="";
	$style=$oddstyle;
	foreach my $arg (@arguments) {
	    $arg =~ s/^\"//; $arg =~ s/\"$//;
	    $line .= "$style$arg$style ";
	    if ($style eq $oddstyle) {$style=$evenstyle}
	    else {$style=$oddstyle}
	}
    } elsif ($line =~  s/^\.ft\s*//) { #
	if (!$line) { # revert
	    $boldline=0;
	    $italicline=0;
	} elsif ($line eq "B") { # set to bold font
	    $boldline=1;
	} elsif ($line eq "I") { # set to italic font
	    $italicline=1;
	}
	$line="";
    } elsif ($line eq ".SM") { # font size - ignore
	next;
### tables - man tbl. groff would post-process this with tbl(1)
    } elsif ($line eq ".TS") { # table start, up until .TE (table end)
	my $table_groff="";
	$line="";
	while (defined($line) && $line !~ /^\.TE/) {
	    $table_groff .= $line;
	    $line=<INPUT>;
	}
	$output .= "\n\n";
	$output .= format_table($table_groff);
	next;
    } elsif ($line =~ s@^\.if\s+@@) { # if conditional statement
	# .if n | t = in nroff/troff mode
	# .if e | o = even/odd page
	# .if v = always false
	# nroff is plain ascii, troff uses fancier markup (eg copyright)
	# we'll use the plain ascii version for now.
	# XXX Todo - use troff and do markup
	if ($line =~ m@^[vt]@) {next} # ignore
	$line =~ s@^n@@; # nroff
### some unknown commands - do they mean Start and End for some postprocessing?
    } elsif ($line =~ m@^\.[DB][SE]@) {
	if ($debug) {print STDERR "warning - skipping $line\n"}
	next;
### catch-all for any other groff tags
    } elsif ($line =~ m@^\.\S+@) {
	print STDERR "unknown markup tag in line \"$line\"\n";
	# remove tag, and hope for the best...
	$line =~ s@^\.\S+\s+@@;
	$filled_text=1;
    } else { # plain text?
	$filled_text=1;
	# protect against wiki special chars
	$line =~ s@^([\*\#])@\\& $1@; # \& is a zero-space (fixed later)
    }


    # print out text, if any
    if ($line) {
	$output .= $indent; # if any
	if ($line =~ /^ /) { # start with space forces a break
	    $output .= "\n ";
	}
	my $indent_colon_workaround=0;
	if ($indent_label==2) {
	    if ($line =~ /\:/) {$indent_colon_workaround=1;$output.="\n";}
	    else {$output .= ";"}
	}
	if ($boldline) {$output .= "__"}
	if ($italicline) {$output .= "''"}
	$output .= $line;
	if ($italicline) {$output .= "''"}
	if ($boldline) {$output .= "__"}
	if ($no_fill == 1) {$output .= " %%%\n"} # output lines as is
	elsif ($filled_text) {$output .= " "} # other commands add the space
	if ($indent_label) {
	    if ($indent_label==2) {
		if ($indent_colon_workaround) {
		    $output .= "\n;";
		}
		$output .= ": ";
	    }
#	    else {$output .= "\n"} # assumes single-line paragraph!
	    $indent_label--;
	}
    }
}

close INPUT;

### convert $output to utf-8, clean up soft hyphens (0xAD), groff chars, etc...

## chars that escape to themselves
#
# \- is a soft hyphen, \\ \. \+?
$output =~ s@([^\\])\\([\/\+\.\-\\])@$1$2@g;

$output =~ s@([^\\])\\e@$1\\@g; # escape chars?

## space characters
#
# \& is a zero width space - we'll remove it. (it is used for breaking tokens?)
$output =~ s@([^\\])\\&@$1@g;
#
# \~ is a non-breaking space
$output =~ s@([^\\])\\-@$1\xc2\xa0@g; # utf8 nbsp
#
# \| and \^ are very thin spaces that are "rounded to zero" for tty devices...
$output =~ s@([^\\])\\[|^]@$1@g;
#
# \0 is "a space the size of a digit"
$output =~ s@([^\\])\\0@$1 @g;

## miscellaneous symbols/characters
$output =~ s@\\\(co\b@\xc2\xa9@g; # utf8 copyright symbol
$output =~ s@\\\(bv@\|@g; # vertical bar
# bullet points
$output =~ s@^\s*;?\\\(bu\s*:@* @gm;
# quote marks
$output =~ s@\\\*q@\"@g;


## convert latin accents to utf-8 unicode
# assume any high-ascii characters sitting by themselves are latin1 accents
$output =~ s@([[:ascii:]])([\x80-\xff])([[:ascii:]])@($1.uni_to_utf8($2).$3)@eg;

# try to recognise references to other manpages
$output =~ s/''(\w+)''\s+(\(\d\w*\))/$1$2/g;
$output =~ s/__(\w+)__\s+(\(\d\w*\))/$1$2/g;

if (0) { # old markup
    # wiki mark-up protection
    $output =~ s@\[@\[\[@g;
    ### finally, escape any wikiwords
    $output =~ s/\b(__)?(([A-Z][a-z]+){2,})/$1!$2/g;
} else { # new markup
    # wiki mark-up protection
    $output =~ s@\[@~\[@g;
    ### finally, escape any wikiwords
    $output =~ s/\b(__)?(([A-Z][a-z]+){2,})/$1~$2/g;
}


print $output . "\n";

exit 0;



### helper functions

# Implement table formatting - would be done by groff sending output to tbl(1)
# see tbl manpage for brief summary of table formatting
sub format_table {
    my $groff_text = shift;
    
    my @lines=split("\n", $groff_text);

    # there may be an optional row before that with global options. I'm not
    # even sure if any man pages use this... (global options line ends with ;)
    # ignore global options
    if ($lines[0] =~ /;/) {shift @lines}

    # can have multiple format lines. Last format line (ends with a .) is for
    # all remaining table rows

    my @format_rows;
    # the format row with the most columns is the table width
    # turn tbl col formatting into wiki formatting styles
    while (1) {
	# move format rows into array
	my $line=shift @lines;
	my $is_last=($line =~ s/\.$//); # this is the last format row
	push @format_rows, $line;
	if ($is_last) {last}
    }
    # find longest format row (for number of columns in table)
    my $numcolumns=0;
    foreach my $format (@format_rows) {
	my @col_formats=split(" ", $format);
	my $rowlength=@col_formats;
	if ($rowlength > $numcolumns) {$numcolumns=$rowlength}
	foreach my $col (@col_formats) {
	    my $bold=0;
	    $col =~ s/^[lrca]//i; # ignore left/right/centred justification
	    if ($col =~ s/^[fF]?B//) {$bold=1} # (font) bold
	    $col =~ s/^f\w\w?//i; # ignore other font formats
	    if ($col) {print STDERR "unknown table column format \"$col\"\n"}
	    if ($bold) {$col="__"}; # wiki bold markup
	}
	$format=join(" ", @col_formats);
    }

    # format lines
    # if the line starts with a ".", it is a groff command
    # if the line is _ or =, a horzontal rule should be drawn
    my $output="";
    my @formats=split(" ", shift @format_rows);
    foreach my $line (@lines) {
	if ($line =~ /^\.[^\d]/) {next} # it's a groff command - ignore
	# determine where each column is (eg single tokens only?)
	# should be separated by tab, unless overridden with tab global option
	# format appropriately
	my @cols = split ("\t", $line);
	my $counter=$#cols;
	while ($counter >= 0) {
	    my $format=$formats[$counter];
	    if ($format) {
		$cols[$counter]=$format.$cols[$counter].$format;
	    }
	    $counter--;
	}
	$output .= "|" . join("|", @cols) . "\n";
	if (@format_rows) {@formats=split(" ", shift @format_rows)}
    }
    return $output;
}



# given a unicode char, return utf-8 of it
sub uni_to_utf8 {
    my $char=ord(shift);
    my $out="";
    if ($char < 0x80) {
    # ascii character
        return chr ($char);
    } elsif ($char < 0x800) {
    # 2 bytes
        return chr(0xc0 + (($char >> 6) & 0x1f)) . chr(0x80 + ($char & 0x3f));
    } elsif ($char < 0x1000) {
    # 3 bytes
        return chr (0xe0 + (($char >> 12) & 0xf)) .
            chr (0xc0 + (($char >> 6) & 0x1f)) .
		chr (0x80 + ($char & 0x3f));
    } else {
        print STDERR "ERROR - can't do large unicode (4byte utf-8) yet";
        return undef;
    }
}
