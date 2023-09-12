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

use strict;

use Test::More;

use Qgoda::Util::Hash qw(set_dot_key);

my $got = {};
my $expect = {};

$expect->{foo}->{bar}->{baz} = 42;
set_dot_key $got, 'foo.bar.baz', 42;
is_deeply $got, $expect, 'simple key';

$expect->{foo}->{bad}->{bus} = 2304;
set_dot_key $got, 'foo.bad.bus', 2304;
is_deeply $got, $expect, 'existing intermediate key';

$expect->{foo}->{bar} = 48;
set_dot_key $got, 'foo.bar', 48;
is_deeply $got, $expect, 'overwriting intermediate key';

$expect->{foo}->{bad}->{bus} = 1989;
set_dot_key $got, 'foo.bad.bus', 1989;
is_deeply $got, $expect, 'overwriting value';

done_testing;
