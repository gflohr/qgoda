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

use Qgoda::Processor;
use Test::More tests => 3;

my ($html, $text, %postmeta);

my $processor = Qgoda::Processor->new;

$text = 'Find me!';
$html = <<EOF;
<h1>Headline</h1>
<p>$text</p>
<footer>ouch</footer>
EOF
%postmeta = $processor->postMeta($html);
is $postmeta{excerpt}, $text;

$text = '  Find   me!   ';
$html = <<EOF;
<h1>Headline</h1>
<p>$text</p>
<ul class="links">
<li><a href="http://www.qgoda.net/">external</a></li>
<li><a href="/path/to/other/">other</a></li>
<li><a href=":colon:">colon</a></li>
<li><a href="%3acolon:">is</a></li>
<li><a href="%3acolon%3a">escaped</a></li>
<li><a href="/path/to/other/">other</a></li>
</ul>
<footer>ouch</footer>
EOF
%postmeta = $processor->postMeta($html);
is $postmeta{excerpt}, 'Find me!';
is_deeply [sort @{$postmeta{links}}], [
    '/path/to/other/',
    ':colon:',
    'http://www.qgoda.net/',
];
