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
use File::Find qw(finddepth);

use Qgoda::CLI;

sub collect_artefacts;
sub prune_site;
sub touch;

my $listing = <<'EOF';
[% IF asset.lingua == 'de' %]
	[% INCLUDE "listing-de.html" %]
[% ELSE %]
	[% INCLUDE "listing-en.html" %]
[% END %]
EOF

my $listing_lingua = <<'EOF';
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
			view => 'listing.html',
		},
		'index.en.md' => {
			title => 'English index page',
			lingua => 'de',
			location => '/index.en.html',
			content => "Listing\n",
			view => 'listing.html',
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
		'_views/listing.html' => $listing,
		'_views/listing-de.html' => $listing_lingua,
		'_views/listing-en.html' => $listing_lingua,
		'_views/post.html' => 'Hello, world!',
	},
);

my ($got, $wanted);

my $qgoda = Qgoda->new;

ok $qgoda->buildForWatch, '1st build';
$got = collect_artefacts;
$wanted = [
	'_site/',
	'_site/de/',
	'_site/de/post/',
	'_site/de/post/index.html',
	'_site/en/',
	'_site/en/post/',
	'_site/en/post/index.html',
	'_site/index.de.html',
	'_site/index.en.html',
];
is_deeply $got, $wanted, 'build 1';
prune_site $got;

$site->tearDown;

done_testing;

sub collect_artefacts {
	my @files;

	my $cb = sub {
			if (-d $File::Find::name) {
					push @files, "$File::Find::name/";
			} else {
					push @files, "$File::Find::name";
			}
	};

	finddepth { wanted => $cb, bydepth => 1, no_chdir => 1 }, '_site';

	return [sort @files];
}

sub prune_site {
	my ($files) = @_;

	foreach my $filename (reverse @$files) {
		if ('/' eq substr $filename, -1) {
			rmdir $filename or die "rmdir '$filename': $!";
		} else {
			unlink $filename or die "unlink '$filename': $!";
		}
	}
}
