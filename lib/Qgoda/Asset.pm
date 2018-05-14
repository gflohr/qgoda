#! /bin/false

# Copyright (C) 2016-2018 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package Qgoda::Asset;

use strict;

use Qgoda::Util qw(merge_data);

sub new {
    my ($class, $path, $relpath) = @_;

    my $self = {};

    # Overwrite these two keys unconditionally.
    $self->{path} = $path;
    $self->{relpath} = $relpath;

    my $reldir = $relpath;
    $reldir =~ s{/[^/]+$}{};
    $self->{reldir} = $reldir;

    bless $self, $class;
}

sub getPath {
    shift->{path};
}

sub getRelpath {
    shift->{relpath};
}

sub getOrigin {
    my ($self) = @_;

    if (exists $self->{origin}) {
        return $self->{origin};
    } else {
        return $self->getPath;
    }
}

sub dump {
    my ($self) = @_;

    %{$self};
}

1;
