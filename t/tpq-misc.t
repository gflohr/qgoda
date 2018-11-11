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

use strict;

BEGIN {
    my $test_dir = __FILE__;
    $test_dir =~ s/[-a-z0-9]+\.t$//i;
    unshift @INC, $test_dir;
}

use TestSite;
use Test::More;

use Qgoda::CLI;
use Qgoda::Util qw(read_file);

my $bust_cache = <<EOF;
[%- USE q = Qgoda -%]

[% q.bustCache('/styles.css') %]

[% q.bust_cache('/styles2.css') %]

relative: [% q.bustCache('styles.css') %]

not-there: [% q.bustCache('not-there.css') %]

[% q.bustCache('/styles.css?foo=1') %]
EOF

my $site = TestSite->new(
	name => 'tpq-misc',
	assets => {
		'bust-cache.md' => {content => $bust_cache},
    },
	files => {
		'_views/default.html' => "[% asset.content %]",
		'styles.css' => '// Test styles',
		'styles2.css' => '// Test styles',
	}
);

ok (Qgoda::CLI->new(['build'])->dispatch);

ok -e '_site/bust-cache/index.html';
my $bust_cache_content = read_file '_site/bust-cache/index.html';
like ($bust_cache_content, qr{<p>/styles\.css\?[0-9]+</p>}, 'bustCache');
like ($bust_cache_content, qr{<p>/styles2\.css\?[0-9]+</p>}, 'bust_cache');
like ($bust_cache_content, qr{<p>relative: styles\.css</p>},
      'bustCache relative');
like ($bust_cache_content, qr{<p>not-there: not-there\.css</p>},
      'bustCache non existing');
like ($bust_cache_content, qr{<p>/styles\.css\?foo=1\&amp;[0-9]+</p>},
      'bustCache with query parameter');

$site->tearDown;

done_testing;
