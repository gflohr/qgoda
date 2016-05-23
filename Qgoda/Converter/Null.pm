#! /bin/false

package Qgoda::Converter::Null;

use strict;

use base qw(Qgoda::Converter);

sub convert { $_[1] }

1;

=head1 NAME

Qgoda::Converter::Null - Default builder for Qgoda posts.