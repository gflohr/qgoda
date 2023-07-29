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

use lib 't';
use TestSite;
use Test::More;
use JSON::PP;

my $site = TestSite->new(name => 'config-defaults',
	config => {
		# All these are allowed because.
		private => {
			_string => 'Hello, world!',
			_number => '2.718',
			_integer => 42,
		},
		site => {
			_object => {foo => 'bar'},
			_array => ['one', 'two', 'three'],
			_boolean => $JSON::PP::false,
			_null => undef,
		},
	},
);
my $x = $site->exception;
ok !$x, 'config variables starting with an underscore should be allowed.';

$site->tearDown.

done_testing;
