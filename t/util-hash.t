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

use Qgoda::Util::Hash qw(set_dotted get_dotted);

my $got = {};
my $expect = {};

$expect->{foo}->{bar}->{baz} = 42;
set_dotted $got, 'foo.bar.baz', 42;
is_deeply $got, $expect, 'simple key';

$expect->{foo}->{bad}->{bus} = 2304;
set_dotted $got, 'foo.bad.bus', 2304;
is_deeply $got, $expect, 'existing intermediate key';

$expect->{foo}->{bar} = 48;
set_dotted $got, 'foo.bar', 48;
is_deeply $got, $expect, 'overwriting intermediate key';

$expect->{foo}->{bad}->{bus} = 1989;
set_dotted $got, 'foo.bad.bus', 1989;
is_deeply $got, $expect, 'overwriting value';

is_deeply(get_dotted($got, 'foo'), $got->{foo}, 'key foo');
is_deeply(get_dotted($got, 'foo.bad'), $got->{foo}->{bad}, 'key foo.bad');
is_deeply(
	get_dotted($got, 'foo.bad.bus'),
	$got->{foo}->{bad}->{bus},
	'key foo.bad.bus'
);
is(get_dotted($got, 'la.la.la'), undef, 'not existing');


done_testing;
