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
included [% asset.overlay %][% asset.extra %]
EOF

my $no_path = <<EOF;
[% USE q = Qgoda %]
before
[% q.include %]
after
EOF

my $no_overlay = <<EOF;
[% USE q = Qgoda %]
before
[% q.include('_includes/other.md') %]
after
EOF

# Cwd::abs_path only returns undef if the file is in a non-existing
# directory. This is important for test coverage.
my $not_existing = <<EOF;
[% USE q = Qgoda %]
before
[% q.include('_includes/not/there.md', asset, extra = '1234') %]
after
EOF

my $site = TestSite->new(
	name => 'tpq-include',
	assets => {
		'with-include.md' => {content => $with_include, overlay => 23},
		'no-path.md' => {content => $no_path},
		'no-overlay.md' => {content => $no_overlay},
		'not-there.md' => {content => $not_existing},
		'_includes/other.md' => {content => $include},
    },
	files => {
		'_views/default.html' => "[% asset.content %]",
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

ok -e '_site/not-there/index.html';
like ((read_file '_site/not-there/index.html'), $invalid, 'not found');

#$site->tearDown;

done_testing;
