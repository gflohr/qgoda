#! /bin/false

package Qgoda::Convertor::Null;

use strict;

use base qw(Qgoda::Convertor);

sub convert { $_[1] }

1;

=head1 NAME

Qgoda::Convertor::Null - Default builder for Qgoda posts.