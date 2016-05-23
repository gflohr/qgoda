#! /bin/false

package Qgoda::Artefact;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');

sub new {
    my ($class, $path) = @_;

    bless {
        path => $path,
    }, $class;
}

1;
