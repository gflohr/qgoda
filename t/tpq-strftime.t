#! /usr/bin/env perl # -*- perl -*-

# Copyright (C) 2016-2025 Guido Flohr <guido.flohr@cantanea.com>,
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

# July 16th, 2023 = 16 heinäkuu
# The Finnish month seems to be 8 bit only.
my $then = 1689511601;
my $heinaekuu = Qgoda::TT2::Plugin::Qgoda->strftime('%B', $then, 'fi');

ok Encode::is_utf8($heinaekuu), 'utf-8 flag on';
ok Encode::is_utf8($heinaekuu, 1), 'valid utf-8 flag';

done_testing;