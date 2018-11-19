#! /usr/bin/env perl # -*- perl -*-

# Copyright (C) 2016-2018 Guido Flohr <guido.flohr@cantanea.com>,
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

use Test::More tests => 10;
use Qgoda::Util qw(strip_suffix);

is_deeply [strip_suffix 'simple.txt'], ['simple', 'txt'], 'simple.txt';
is_deeply [strip_suffix 'index.html.utf8.de'], ['index', 'html', 'utf8', 'de'], 'index.html.utf8.de';
is_deeply [strip_suffix 'version-0.2-released.md'], ['version-0.2-released', 'md'], 'version-0.2-released.md';
is_deeply [strip_suffix 'foo.bar.stop-here.foo.bar.txt'], ['foo.bar.stop-here', 'foo', 'bar', 'txt'], 'foo.bar.stop-here.foo.bar.txt';
is_deeply [strip_suffix 'simple..txt'], ['simple', 'txt'], 'simple..txt';
is_deeply [strip_suffix 'README'], ['README'], 'README';
is_deeply [strip_suffix 'dot.'], ['dot'], 'dot.';
is_deeply [strip_suffix 'dotdot..'], ['dotdot'], 'dotdot..';
is_deeply [strip_suffix 'dot.no-suffix'], ['dot.no-suffix'], 'dot.no-suffix';
is_deeply [strip_suffix 'co.ll...a...p...s...e...'], ['co', 'll', 'a', 'p', 's', 'e'], 'co.ll...a...p...s...e...';
