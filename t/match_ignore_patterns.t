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

use Qgoda::Util qw(match_ignore_patterns);

my @patterns;

@patterns = q(foobar.txt);

ok match_ignore_patterns(\@patterns, 'foobar.txt'), 'equality';
ok !match_ignore_patterns(\@patterns, 'xyzfoobar.txt'), 'incomplete match';
ok match_ignore_patterns(\@patterns, '/path/to/foobar.txt'), 'subdir match';
