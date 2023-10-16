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
use Test::More;

my ($html, $text, %postmeta);

my $processor = Qgoda::Processor->new;

$text = 'Find me!';
$html = <<'EOF';
<p>This is the excerpt.</p>

<div><x:tag>foobar</x:tag></div>
EOF

%postmeta = $processor->postMeta($html);

is $postmeta{content_body}, '<div><x:tag>foobar</x:tag></div>';

done_testing;

