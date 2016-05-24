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

use Test::More tests => 3;
use Qgoda::Util;

sub tokenize { &Qgoda::Util::tokenize };

my ($input, $expect, $got);

$input = qq{12.34e4};
$expect = [n => 123400];
$got = tokenize $input;
is_deeply $got, $expect, 'lone float';

$input = qq{site-wide};
$expect = [v => 'site-wide'];
$got = tokenize $input;
is_deeply $got, $expect, 'hyphen in variable names';


$input = qq{drink-7up};
$expect = [v => 'drink-7up'];
$got = tokenize $input;
is_deeply $got, $expect, 'hyphen in variable names with numbers';
