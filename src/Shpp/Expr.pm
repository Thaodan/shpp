#!/usr/bin/perl
package Shpp::Expr;
use feature "switch";
use strict;
no warnings 'experimental';
my %operators = (
    '=' =>,
    '>' =>,
    '<' =>,
    '!' =>,
);

sub init {
    my $class = shift();
    my $self  = {};

    bless( $self, $class );
    return $self;
}

=head1 parse

=head2 Intro

This function parses unparsed strings and seperates chars by the split rules

=head2 Syntax

C<parse("string")>


=head2 Returns

parsed string in an array with an entry for every word

=cut 

sub parse {
    my $operators_str;
    my $non_empty_test;    # see below
                           # build regex rdy string of all equal operators
    for my $equals (%operators) {

        if ($non_empty_test)    # dirty workaround to prevent space operator
        {
            $operators_str = "$operators_str,$equals";
        }
        else {
            #say(2);
            $operators_str  = "$equals";
            $non_empty_test = 1;
        }
    }

    #say($equal_operators_str);
    my @split_expr = split( "", $_[0] );
    shift();
    my @return_expr;
    my ( $cur_word, $last_char_type );

    for my $cur_char (@split_expr) {
        given ($cur_char) {

            # just a normal char
            when (m/[Aa-zZ,0-9]/) {

                # do we got single char test or assignation?
                if ( $last_char_type =~ m/[$operators_str]/ ) {

                    # ok we got it end word and start a new one
                    push( @return_expr, $last_char_type );
                    $cur_word = "$cur_char";
                }
                else    # else continue current word
                {
                    $cur_word = "$cur_word$cur_char";
                }
                $last_char_type = $cur_char;
            }

            # equal begins
            when (m/[$operators_str]/) {
                given ($last_char_type) {

                    # equal end
                    when (m/[$operators_str]/) {
                        push( @return_expr, "$cur_word$cur_char" );
                    }

                    # last char was no operator
                    default {
                        if ( $last_char_type !~ m/$operators_str/ ) {

                            # got single char word
                            push( @return_expr, $last_char_type );
                            $cur_word = "$cur_char";
                        }
                        else {
                            $cur_word = "$last_char_type$cur_char";
                            push( @return_expr, $cur_word );
                        }
                    }
                }
                $last_char_type = $cur_char;
            }

            # got space, word done
            when (" ") {
                push( @return_expr, $cur_word );
                $cur_word = '';
            }
        }
    }

    #push last word to returned array
    if ( $cur_word != '' ) {
        push( @return_expr, $cur_word );
    }

    return (@return_expr);
}

# Local Variables:
# mode: cperl
# cperl-indent-level: 3
# indent-tabs-mode: nil
# eval: (cperl-set-style "C++")
# End:
