package Babel;
use Bind;
no warnings 'experimental';
use feature 'switch';
my $modes = Bind->new();
sub __init__()
{
   if ( not $externals )
   {
      return; 
   }
}
__init__();

=pod 

add mode 
syntax:
Register('org', { export => 's' } );

=cut
sub Register
{
   my $mode = shift();
   my $m_sub = shift();

   my %tmp_mode_key = ( self => $m_sub,
			args => (),
		      );

   my $args = shift();
   if ( ref $args == ref {} )
   {
       $tmp_mode_key{args} = \%{$args};
   }
   $modes->add(\%tmp_mode_key);
}
# command to call in code
sub begin_src
{
    my $mode = shift();
    my $sub_arg; # true if we current arg needs next arg as sub arg
    my $last_arg;
    my %parsed_args; # arguments that we pass to our handler
    if ( exists $modes->{subs}{$mode} )
    {
       for my $arg ( @_ ) 
       {
	  if ( $sub_arg )
	  # test if current arg doesn't start a new argument and put it into %parsed_args
	  {
	     error("argument $last_arg needs an argument") if $arg =~ s/^://;
	     $parsed_args{$last_arg} = $arg;
	     $sub_arg = 0; # reset
	  }
	  else
	  {
	     if ( $arg =~ s/^://) # do we got an argument? 
	     {
		if ( exists $modes->{subs}{$mode}{args}{$arg} )
		{
		   given ( $modes->{subs}{$mode}{args}{$arg} )
		   {
		      when ( 's')
		      {
			 $sub_arg = 1;
			 $last_arg = $arg;
		      }
		      default
		      {
			 warn("unkown paramter type $modes->{subs}{$mode}{args}{$arg}");
		      }
		   }
		}
		else 
		{
		   error("unkown argument $arg");
		}
	     }
	  }
	 
       }
       &{$modes->{self}{$mode}{self}}(\%parsed_args, @_);
    }
    else
    {
       error("unkown mode $mode");
    }
    
}

$externals->add('begin_src', begin_src, 'ALL');
