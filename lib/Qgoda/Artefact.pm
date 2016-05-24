#! /bin/false

package Qgoda::Artefact;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');

sub new {
    my ($class, $path, $asset) = @_;

    bless {
        path => $path,
        asset => $asset,
    }, $class;
}

sub getPath {
	shift->{path};
}

sub getAsset {
    shift->{asset};
}

1;
