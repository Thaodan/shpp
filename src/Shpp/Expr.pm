#!/usr/bin/perl
package Shpp::Expr;
use Switch;
no warnings 'experimental';
my %equal_operators = (
		      '=' =>,
		      '>' =>,
		      '<' =>,
		      '!' =>,
);

sub init()
{
   my $class = shift();
   my $self = {};
   
   bless($self, $class);
   return $self;
}

sub parse 
{
   my @split_expr = split("", $_[0]);
   shift();
   my @return_expr;
   my ( $cur_word, $last_char_type );

   for my $cur_char ( @split_expr )
   {
      switch($cur_char)
      {
	 # just a normal char
	 case(m/[Aa-zZ,0-9]/)	   
	 {
	    $cur_word+=$cur_char;
	    $last_char_type='char';
	 }
	 case(m/[%equal_operators,\\]/)
	 {
	    switch($last_char_type)
	    {
	       # cur char was escaped ignore it and add it to $cur_word
	       case ( '\\' )
	       {
		  $cur_word+=$cur_char;
	       }
	       case ( m/[%equal_operators]/)
	       {
		  $cur_word=$last_char_type+$cur_char;
	       }
	       else 
	       {
		  $last_char_type = $cur_char;
		  # escape sign needs to be in returned string
		  $cur_word+=$cur_char if $cur_char == '\\'; 
	       }
	    }
	 }
	 # word done
	 case(m/\s,\t/)
	 {
	  #  $return_expr[-1] = $cur_word;
	    $cur_word = '';
	 }
      }
   }   
}
