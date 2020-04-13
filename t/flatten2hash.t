#! /usr/bin/env perl # -*- perl -*-

# Copyright (C) 2016-2020 Guido Flohr <guido.flohr@cantanea.com>,
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

use common::sense;

use Test::More tests => 2;

use Qgoda::Util qw(flatten2hash);

my $hash = {
    zero => 0,
    one => 1,
    two => 2,
    deeply => {
        nested => {
            hash => {
                foo => 'bar',
            },
            array => [23, 4, 89],
        },
    },
    empty_hash => {},
    empty_array => [],
};

is_deeply flatten2hash($hash), {
    zero => 0,
    one => 1,
    two => 2,
    'deeply.nested.hash.foo' => 'bar',
    'deeply.nested.array.0' => 23,
    'deeply.nested.array.1' => 4,
    'deeply.nested.array.2' => 89,
    'empty_hash' => {},
    'empty_array' => [],
};

my $array = [the => $hash];
is_deeply flatten2hash($array), {
    0 => 'the',
    '1.zero' => 0,
    '1.one' => 1,
    '1.two' => 2,
    '1.deeply.nested.hash.foo' => 'bar',
    '1.deeply.nested.array.0' => 23,
    '1.deeply.nested.array.1' => 4,
    '1.deeply.nested.array.2' => 89,
    '1.empty_hash' => {},
    '1.empty_array' => [],
};
