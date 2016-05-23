#! /bin/false

package Qgoda::Asset;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');

sub new {
    my ($class, $path, $relpath) = @_;

    bless {
        path => $path,
        relpath => $relpath,
    }, $class;
}

sub getPath {
	shift->{path};
}

sub getRelpath {
	shift->{relpath};
}

1;
