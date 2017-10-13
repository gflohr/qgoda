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

use Test::More tests => 11;

use Qgoda::Util qw(match_ignore_patterns);

my @patterns;

@patterns = q(foobar.txt);

ok match_ignore_patterns(\@patterns, '/foobar.txt'), 'equality';
ok !match_ignore_patterns(\@patterns, '/xyzfoobar.txt'), 'incomplete match';
ok match_ignore_patterns(\@patterns, '/path/to/foobar.txt'), 'subdir match';

@patterns = q(/foobar.txt);
ok match_ignore_patterns(\@patterns, '/foobar.txt'), 'top-level match';
ok !match_ignore_patterns(\@patterns, '/path/to/foobar.txt'), 'subdir match2';

@patterns = ('*.txt', '!foobar.txt');
ok match_ignore_patterns(\@patterns, '/barbaz.txt'), 'simple negate matched';
ok !match_ignore_patterns(\@patterns, '/foobar.txt'), 'simple negate failed';

# Whitespace after an exclamation mark inside pattern must be removed.
@patterns = ('*.txt', '!        foobar.txt');
ok match_ignore_patterns(\@patterns, '/barbaz.txt'), 'simple negate matched';
ok !match_ignore_patterns(\@patterns, '/foobar.txt'), 'simple negate failed';

@patterns = q(foobar/);
ok match_ignore_patterns(\@patterns, 'foobar', 1), 
    'dirmatch did not match for directory';
ok !match_ignore_patterns(\@patterns, 'foobar'), 
    'dirmatch matched for non-directory';

# TODO:
# - Files that reside inside a directory that was previously excluded cannot
#   be included again.  This is needed so that the watch functionality 
#   matches that of the file collector.
