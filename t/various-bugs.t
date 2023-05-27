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

my ($site, $x);

$site = TestSite->new(name => 'config-syntax-error',
	files => {
		'_config.yaml' => 'foo: "bar',
	},
);

$x = $site->exception;
ok $x, 'syntax error in configuration should throw YAMLException';
like $x, qr/^_config\.yaml: YAMLException/;

$site->tearDown.

done_testing;
