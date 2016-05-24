#! /usr/bin/env perl # -*- perl -*-

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

use strict;

use Test::More tests => 14;
use Qgoda::Util;

sub extract_number($) {
	&Qgoda::Util::extract_number;
}

cmp_ok((extract_number "2304"), '==', 2304, 'integer');
cmp_ok((extract_number "2304qgoda"), '==', 2304, 'integer with trailing garbage');
cmp_ok((extract_number "0b101010qgoda"), '==', 42, 'binary with trailing garbage');
cmp_ok((extract_number "0b1010102qgoda"), '==', 42, 'binary with trailing non-binary');
cmp_ok((extract_number "+2304"), '==', 2304, 'integer with plus sign');
cmp_ok((extract_number "-2304"), '==', -2304, 'integer with minus sign');
my ($number, $rest) = extract_number "2304.";
cmp_ok $number, '==', 2304, 'trailing dot';
is $rest, '.', 'trailing dot consumed';
cmp_ok((extract_number "42.123qgoda"), '==', 42.123, 'float');
cmp_ok((extract_number "+42.123"), '==', 42.123, 'float with plus sign');
cmp_ok((extract_number "-42.123"), '==', -42.123, 'float with minus sign');
cmp_ok((extract_number "+42.123e10"), '==', 42.123e10, 'float with exponential notation');
cmp_ok((extract_number "+42.123e+10"), '==', 42.123e10, 'float with positive exponential notation');
cmp_ok((extract_number "+42.123e-10"), '==', 42.123e-10, 'float with negative exponential notation');
