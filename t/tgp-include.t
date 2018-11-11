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

my $site = TestSite->new(
	name => 'tgp-misc',
	assets => {
		'with-include.md' => {content => $with_include, overlay => 23},
    },
	files => {
		'_views/default.html' => "[% asset.content %]",
		'_includes/other.md' => $include,
	}
);

ok (Qgoda::CLI->new(['build'])->dispatch);

ok -e '_site/with-include/index.html';
is ((read_file '_site/with-include/index.html'), 
    '<p>included 2304</p>', 'include');

$site->tearDown;

done_testing;
