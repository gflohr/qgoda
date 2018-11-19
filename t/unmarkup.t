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

use Test::More tests => 4;

use Qgoda::Util qw(unmarkup);

my ($html);

$html = 'Hello, world!';

is unmarkup $html, $html;

$html = 'Hello, <em>world!</em>';
is unmarkup $html, 'Hello, world!';

$html = 'What is <a href="solution" title="a < b">a &lt; b</a>?';
is unmarkup $html, 'What is a &lt; b?';

$html = 'Hello, <![CDATA[<world>]]>!';
is unmarkup $html, 'Hello, <world>!';
