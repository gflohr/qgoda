#! /bin/false

# Copyright (C) 2016-2023 Guido Flohr <guido.flohr@cantanea.com>,
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

package Qgoda::Util::Hash;

use strict;

#VERSION

use File::Spec;

use base 'Exporter';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(get_dotted set_dotted);

sub get_dotted($$) {
	my ($hash, $path) = @_;

	my $addr = $hash;
	my @path = split /\./, $path;
	my $last = pop @path;
	foreach my $key (@path) {
		if (!exists $addr->{$key} || !ref $addr->{$key}) {
			return;
		}
		$addr = $addr->{$key};
	}

	return if !exists $addr->{$last};

	return $addr->{$last};
}

sub set_dotted($$$) {
	my ($hash, $path, $value) = @_;

	my $addr = $hash;
	my @path = split /\./, $path;
	my $last = pop @path;
	foreach my $key (@path) {
		if (!exists $addr->{$key} || !ref $addr->{$key}) {
			$addr->{$key} = {};
		}
		$addr = $addr->{$key};
	}
	$addr->{$last} = $value;

	return $hash;
}

1;
