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

use JSON;

use Qgoda::CLI;
use Qgoda::Util qw(read_file);

my %assets;
my $num_docs = 13;
my $num = 28;

$assets{"en/post-1.md"} = {
	content => 'Good morning!',
	tags => ['greeting', 'morning'],
	type => 'post',
};
$assets{"fi/post-1.md"} = {
	content => 'Hyvää huomenta!',
	tags => ['tervehdys', 'aamu'],
	type => 'post',
};
$assets{"en/post-2.md"} = {
	content => 'Good morning, too!',
	tags => ['reply', 'morning'],
	type => 'post',
};
$assets{"fi/post-2.md"} = {
	content => 'Huomenta huomenta!',
	tags => ['vastaus', 'aamu'],
	type => 'post',
};
$assets{"en/post-4.md"} = {
	content => 'Good bye!!',
	categories => ['Farewell'],
	type => 'post',
};
$assets{"fi/post-4.md"} = {
	content => 'Hei hei!',
	categories => ['Jäähyväiset'],
	type => 'post',
};
$assets{"en/page-5.md"} = {
	content => 'October',
	tags => ['month'],
	type => 'page',
};
$assets{"fi/page-5.md"} = {
	content => 'lokakuu!',
	tags => ['month'],
	type => 'page',
};

my $taxonomies = <<EOF;
[%- USE q = Qgoda -%]
[%- q.encodeJSON(q.ltaxonomyValues('tags' type = 'post')) -%]
EOF

$assets{"en/taxonomies.md"} = {
	content => $taxonomies,
	priority => -9999,
	chain => 'xml',
};
$assets{"fi/taxonomies.md"} = {
	content => $taxonomies,
	priority => -9999,
	chain => 'xml',
};

my $site = TestSite->new(
	name => 'tpq-taxonomies',
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

my ($json, $values, $expected);

ok -e './_site/en/taxonomies/index.md';
$json = read_file '_site/en/taxonomies/index.md';
$values = eval { decode_json $json };
ok !$@, $@;
$expected = ['greeting', 'morning', 'reply'];
is_deeply $values, $expected;

ok -e './_site/fi/taxonomies/index.md';
$json = read_file '_site/fi/taxonomies/index.md';
$values = eval { decode_json $json };
ok !$@, $@;
$expected = ['aamu', 'tervehdys', 'vastaus'];
is_deeply $values, $expected;

$site->tearDown;

done_testing;
