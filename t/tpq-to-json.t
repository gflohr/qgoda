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
use Encode;

use Qgoda::TT2::Plugin::Qgoda;

my $data = { foo => 'bar' };

is(Qgoda::TT2::Plugin::Qgoda->toJSON($data),
	'{"foo":"bar"}', 'basic encoding');
is(Qgoda::TT2::Plugin::Qgoda->toJSON($data, 'space_after'),
	'{"foo": "bar"}', 'basic encoding');
eval { Qgoda::TT2::Plug::Qgoda->toJSON($data, 'indent_with_tabs_ffs') };
ok $@, 'throw exception for unsupported option';

done_testing;
