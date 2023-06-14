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

use lib 't';
use TestSite;
use Test::More;
use File::Spec;

use Qgoda::CLI;

my $listing = <<'EOF';
[% USE q = Qgoda %]
<ul>
[% FOREACH post IN q.llistPosts() %]
	<li>[% post.title %]</li>
[% END %]
</ul>
EOF

my $site = TestSite->new(
	name => 'deptracker',
	assets => {
		'index.de.md' => {
			title => 'Deutsche Index-Seite',
			lingua => 'de',
			location => '/index.de.html',
			content => "Liste\n",
			view => 'listing-de.html',
		},
		'index.en.md' => {
			title => 'English index page',
			lingua => 'de',
			location => '/index.en.html',
			content => "Listing\n",
			view => 'listing-en.html',
		},
		'de/post.md' => {
			title => 'Deutsche Seite',
			lingua => 'de',
			location => '/de/post/index.html',
			content => 'Quatsch',
			view => 'post.html',
		},
		'en/post.md' => {
			title => 'English post',
			lingua => 'en',
			location => '/en/post/index.html',
			content => 'nonsense',
			view => 'post.html',
		},
	},
	files => {
		'_views/listing-de.html' => $listing,
		'_views/listing-en.html' => $listing,
		'_views/post.html' => 'Hello, world!',
	},
);

ok (Qgoda::CLI->new(['build'])->dispatch);
ok -e '_site/index.de.html', '/index.de.html';
ok -e '_site/index.en.html', '/index.en.html';
ok -e '_site/de/post/index.html', '/de/post/index.html';
ok -e '_site/en/post/index.html', '/en/post/index.html';

$site->tearDown;

done_testing;
