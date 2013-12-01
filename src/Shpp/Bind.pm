#!/usr/bin/perl
package Shpp::Bind;

=pod

my $namespace bind->new();
my %rem = (
    self = rem,
    args = 0,
);
$namspace->add( \%rem );

=cut
use Scalar::Util qw(reftype);
our %subs;

sub new()
{
    my $class = shift();
    my $self = {};

    bless($self, $class);
    return $self;
}

=pod

add sub key to %subs either as hash ref or as by creating a new hash
syntax1: add(keyname, sub-name, 0) # 0 = needed arguments
syntax2: add(\%msg_ref)

=cut 
sub add
{
  my $self = shift();
  my $key = shift();
  if ( reftype $key eq reftype {} )
  {
      $self->{subs}{$key} = \%{$key};
  }
  else
  {
     my $sub = shift();
     my $args = shift();

     $self->{subs}{$key} = { 'self' => $sub,
			     'args' => $args };
  }
}

=pod

search for sub key in %subs and return it if found

=cut

sub get
{
  my $self = shift();
  my $key = shift();

  if ( exists $self->{subs}{$key} )
  {
      return $self->{subs}{$key};
  }
  else
  {
      return;
  }
}

=pod 

remove sub key from %subs
=cut 
sub rm
{
  my $self = shift();
  my $key = shift();
  
  delete $self->{subs}{$key};
}

return 1;
