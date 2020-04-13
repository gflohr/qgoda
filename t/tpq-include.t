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

use common::sense;

use lib 't';
use TestSite;
use Test::More;

use Qgoda::CLI;
use Qgoda::Util qw(read_file);

my $with_include = <<EOF;
[%- USE q = Qgoda -%]
[%- q.include('_includes/other.md', asset, extra => '04') -%]
EOF

my $no_extra = <<EOF;
[%- USE q = Qgoda -%]
[%- q.include('_includes/other.md', asset) -%]
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

my $include_invalid_template = <<EOF;
[% USE q = Qgoda %]
[%- q.include('_includes/invalid.md', asset, extra => '04') -%]
EOF
my $invalid_include = <<EOF;
[% USE q = Qgoda %]
[% q.list('foo', 'bar', 'baz') %]
EOF

my $site = TestSite->new(
	name => 'tpq-include',
	assets => {
		'with-include.md' => {content => $with_include, overlay => 23},
		'no-extra.md' => {content => $no_extra},
		'no-path.md' => {content => $no_path},
		'no-overlay.md' => {content => $no_overlay},
		'not-there.md' => {content => $not_existing},
		'invalid.md' => {content => $include_invalid_template},
		'_includes/other.md' => {content => $include},
		'_includes/invalid.md' => {content => $invalid_include},
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

ok -e '_site/no-extra/index.html';
is ((read_file '_site/no-extra/index.html'), 
    '<p>included</p>', 'include');

my $invalid = qr/^\[\% '' \%\]/;

ok -e '_site/no-path/index.html';
like ((read_file '_site/no-path/index.html'), $invalid, 'no path');

ok -e '_site/no-overlay/index.html';
like ((read_file '_site/no-overlay/index.html'), $invalid, 'no overlay');

ok -e '_site/not-there/index.html';
like ((read_file '_site/not-there/index.html'), $invalid, 'not found');

ok -e '_site/invalid/index.html';
like ((read_file '_site/invalid/index.html'), $invalid, 'invalid include');

$site->tearDown;

done_testing;
