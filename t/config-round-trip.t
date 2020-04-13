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

use lib 't';
use TestSite;
use Test::More;

use Qgoda;

my $site = TestSite->new(name => 'config-round-trip');
my $config = Qgoda->dumpConfig;
ok $config;
$site->tearDown;

$site = TestSite->new(name => 'config-round-trip', config => $config);
my $config2 = Qgoda->dumpConfig;
ok $config2;
is_deeply $config2, $config;
$site->tearDown;

done_testing;
