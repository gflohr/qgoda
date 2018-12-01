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

use lib 't';
use TestSite;
use Test::More;

use Qgoda::CLI;
use Qgoda::Util qw(read_file);

my $with_clone = <<EOF;
[%- USE q = Qgoda -%]
count: [% asset.count %]
[%- IF asset.start < 3 -%]
[%- location = '/clones/index-' _ asset.count _ '.html' -%]
[%- q.clone(location = location start = asset.start + 1 count = asset.count + 1) -%]
[%- END -%]
EOF

my $without_location = <<EOF;
[%- USE q = Qgoda -%]
[%- IF !asset.start -%]
[%- q.clone(start = asset.start + 1) -%]
[%- END -%]
EOF

my $site = TestSite->new(
	name => 'tpq-clone',
	assets => {
		'with-clone.md' => {content => $with_clone, count => 2304},
		'without-location.md' => {content => $without_location},
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

ok -e '_site/with-clone/index.html';
is ((read_file '_site/with-clone/index.html'), 
	'<p>count: 2304</p>', 'clone');

ok -e '_site/clones/index-2304.html';
is ((read_file '_site/clones/index-2304.html'), 
	'<p>count: 2305</p>', 'clone 2304');

ok -e '_site/clones/index-2305.html';
is ((read_file '_site/clones/index-2305.html'), 
	'<p>count: 2306</p>', 'clone 2305');

ok -e '_site/clones/index-2306.html';
is ((read_file '_site/clones/index-2306.html'), 
	'<p>count: 2307</p>', 'clone 2306');

ok ! -e '_site/clones/index-2307.html';

my $invalid = qr/^\[\% '' \%\]/;

ok -e '_site/without-location/index.html';
like ((read_file '_site/without-location/index.html'), 
	$invalid, 'missing location');

$site->tearDown;

done_testing;
