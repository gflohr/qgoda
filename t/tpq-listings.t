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

use Qgoda::CLI;
use Qgoda::Util qw(read_file);

my %assets;
my $num_docs = 13;
my $num = 28;

foreach my $count (1 .. $num_docs) {
	my $count0 = sprintf '%02u', $count;
	$assets{"en/post-$count0.md"} = {
		title => "English #$count0",
		lingua => 'en',
		type => 'post',
		content => 'Good morning!',
		name => "post-$count0",
	};
	$assets{"fi/post-$count0.md"} = {
		title => "Suomalainen #$count0",
		lingua => 'fi',
		type => 'post',
		content => 'Hyvää huomenta!',
		name => "post-$count0",
	};
	$assets{"en/reply-$count0.md"} = {
		title => "English #$count0",
		lingua => 'en',
		type => 'reply',
		content => 'Good morning, too!',
		name => "post-$count0",
	};
	$assets{"fi/reply-$count0.md"} = {
		title => "Suomalainen #$count0",
		lingua => 'fi',
		type => 'reply',
		content => 'Huomenta huomenta!',
		name => "post-$count0",
	};
}

my $num_posts_en = <<EOF;
[%- USE q = Qgoda -%]
[%- q.llistPosts.size -%]
EOF
$assets{"en/num-posts.md"} = {
	lingua => 'en',
	type => 'listing',
	content => $num_posts_en,
	priority => -9998
};

my $num_en = <<EOF;
[%- USE q = Qgoda -%]
[%- q.llist.size -%]
EOF
$assets{"en/num.md"} = {
	lingua => 'en',
	type => 'listing',
	content => $num_en,
	priority => -9999
};

my $num_posts_fi = <<EOF;
[%- USE q = Qgoda -%]
[%- q.llistPosts.size -%]
EOF
$assets{"fi/num-posts.md"} = {
	lingua => 'fi',
	type => 'listing',
	content => $num_posts_fi,
	priority => -9998
};

my $num_fi = <<EOF;
[%- USE q = Qgoda -%]
[%- q.llist.size -%]
EOF
$assets{"fi/num.md"} = {
	lingua => 'fi',
	type => 'listing',
	content => $num_fi,
	priority => -9999
};

my $site = TestSite->new(
	name => 'tpq-listings',
	assets => \%assets,
	files => {
		'_views/default.html' => "[% asset.content %]"
	},
	config => {
		defaults => [
			{
				files => '/en',
				values => { lingua => 'en' },
			},
			{
				files => '/fi',
				values => { lingua => 'fi' },
			},
		]
	}
);

ok (Qgoda::CLI->new(['build'])->dispatch);

foreach my $count (1 .. $num_docs) {
	my $count0 = sprintf '%02u', $count;
	ok -e "./_site/en/post-$count0/index.html";
	ok -e "./_site/fi/post-$count0/index.html";
	ok -e "./_site/en/reply-$count0/index.html";
	ok -e "./_site/fi/reply-$count0/index.html";
}

ok -e './_site/en/num-posts/index.html';
is ((read_file './_site/en/num-posts/index.html'), "<p>$num_docs</p>");

ok -e './_site/fi/num-posts/index.html';
is ((read_file './_site/fi/num-posts/index.html'), "<p>$num_docs</p>");

ok -e './_site/en/num/index.html';
is ((read_file './_site/en/num/index.html'), "<p>$num</p>");

ok -e './_site/fi/num/index.html';
is ((read_file './_site/fi/num/index.html'), "<p>$num</p>");

$site->tearDown;

done_testing;
