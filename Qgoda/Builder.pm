#! /bin/false

package Qgoda::Builder;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');

sub new {
    my ($class) = @_;

    require Qgoda;
    my $logger = Qgoda->new->logger('analyzer');

    bless {
    	__logger => $logger,
    }, $class;
}

1;
