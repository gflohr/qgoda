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

my $with_include = <<EOF;
[%- USE q = Qgoda -%]
[%- q.include('_includes/other.md', asset, extra => '04') -%]
EOF

my $include = <<EOF;
---
title: other
---
included [% asset.overlay %][% asset.extra %]
EOF

my $no_path = <<EOF;
---
title: no path
---
[% USE q = Qgoda %]
before
[% q.include %]
after
EOF

my $no_overlay = <<EOF;
---
title: no overlay
---
[% USE q = Qgoda %]
before
[% q.include('_includes/other.md') %]
after
EOF

my $site = TestSite->new(
	name => 'tpq-include',
	assets => {
		'with-include.md' => {content => $with_include, overlay => 23},
		'no-path.md' => {content => $no_path},
		'no-overlay.md' => {content => $no_overlay}
    },
	files => {
		'_views/default.html' => "[% asset.content %]",
		'_includes/other.md' => $include,
	}
);

# Temporarily close stderr while building the site.
open my $olderr, '>&STDERR' or die "cannot dup stderr: $!";
close STDERR;
ok(Qgoda::CLI->new(['build'])->dispatch);
open STDERR, '>&', $olderr;

ok -e '_site/with-include/index.html';
is ((read_file '_site/with-include/index.html'), 
    '<p>included 2304</p>', 'include');

my $invalid = qr/^\[\% '' \%\]/;

ok -e '_site/no-path/index.html';
like ((read_file '_site/no-path/index.html'), $invalid, 'no path');

ok -e '_site/no-overlay/index.html';
like ((read_file '_site/no-overlay/index.html'), $invalid, 'no overlay');

$site->tearDown;

done_testing;
