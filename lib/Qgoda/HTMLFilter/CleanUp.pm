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

package Qgoda::HTMLFilter::CleanUp;

use strict;

use Qgoda;

sub new {
	my ($class, %args) = @_;

	bless {}, $class;
}

sub comment {
	my ($self, $chunk, %args) = @_;

	if ($chunk =~ /^<!--\[if/i) {
	   return $chunk;
	}

	return '';
}

1;
