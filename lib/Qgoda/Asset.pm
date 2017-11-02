#! /bin/false

# Copyright (C) 2016 Guido Flohr <guido.flohr@cantanea.com>, 
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
    my ($class, $path, $relpath, $defaults) = @_;

	if (!$defaults) {
		require Carp;
		Carp::croak("Qgoda::Asset now needs defaults");
	}
	
    my @partials = ($relpath);
	my $current = $relpath;
	# The 'x' is needed by the Visual Studio Code syntax highlighter ...
	while ($current =~ s{/[^/]+$}{}x) {
		push @partials, $current;
	}
	push @partials, '/';

	my $self = {};

	foreach my $partial (@partials) {
		if (exists $defaults->{$partial}) {
			merge_data $self, $defaults->{$partial};
		}
	}

	# Overwrite these two keys unconditionally.
	$self->{path} = $path;
	$self->{relpath} = $relpath;

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
