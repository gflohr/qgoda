#! /usr/bin/env perl # -*- perl -*-

# Copyright (C) 2016-2025 Guido Flohr <guido.flohr@cantanea.com>,
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
my $content;

my $football = <<EOF;
[% USE q = Qgoda %]
<a href="http://www.qgoda.net/">Qgoda</a>
[% q.lanchor(name = 'fava') %]
EOF
$assets{"en/football.md"} = {
	title => "Football",
	type => 'post',
	content => $football,
	name => "football",
	tags => ['ball sports', 'team sport'],
	categories => ['Sports'],
	threshold => 0,
	filters => {},
};
$assets{"de/fussball.md"} = {
	title => "Fußball",
	type => 'post',
	content => $football,
	name => "football",
	tags => ['Ballsportarten', 'Mannschaftssportarten'],
	categories => ['Sport'],
	threshold => 0,
	filters => {},
};

my $tennis = <<EOF;
[% USE q = Qgoda %]
<a href="http://www.qgoda.net/">Qgoda</a>
[% q.lanchor(name='football') %]
EOF
$assets{"en/tennis.md"} = {
	title => "Tennis",
	type => 'post',
	content => $tennis,
	name => "tennis",
	tags => ['ball sports', 'individual sport'],
	categories => ['Sports'],
	threshold => 4,
	filters => { type => 'post' },
};
$assets{"de/tennis.md"} = {
	title => "Tennis",
	type => 'post',
	content => $tennis,
	name => "tennis",
	tags => ['Ballsportarten', 'Einzelsportarten'],
	categories => ['Sport'],
	threshold => 4,
	filters => { type => 'post' },
};

my $long_jump = <<EOF;
[% USE q = Qgoda %]
<a href="http://www.example.com/">Example</a>
EOF
$assets{"en/long-jump.md"} = {
	title => "Long Jump",
	type => 'post',
	content => $long_jump,
	name => "long-jump",
	tags => ['athletics', 'individual sport'],
	categories => ['Sports'],
	threshold => 0,
	filters => { type => 'post' },
};
$assets{"de/weitsprung.md"} = {
	title => "Weitsprung",
	type => 'post',
	content => $long_jump,
	name => "long-jump",
	tags => ['Leichtathletik', 'Einzelsportarten'],
	categories => ['Sport'],
	threshold => 0,
	filters => { type => 'post' },
};

my $fava = <<EOF;
[% USE q = Qgoda %]
<a href="http://www.qgoda.net/">Qgoda</a>
<a href="http://www.example.com/">Example</a>
EOF
$assets{"en/fava.md"} = {
	title => "Fava",
	type => 'recipe',
	content => $fava,
	name => 'fava',
	tags => ['vegan', 'starter', 'greek'],
	categories => ['cooking'],
	threshold => 0,
	filters => {}
};
$assets{"de/fava.md"} = {
	title => "Fava",
	type => 'recipe',
	content => $fava,
	name => 'fava',
	tags => ['vegan', 'Vorspeise', 'griechisch'],
	categories => ['Kochen'],
	threshold => 0,
	filters => {}
};

my $view = <<'EOF';
[%- USE q = Qgoda -%]
[%- FOREACH doc IN q.lrelated(asset.threshold, asset.filters) %]
[% doc.permalink %] ([% q.relation(doc) %])
[%- END -%]

EOF

my $site = TestSite->new(
	name => 'tpq-related',
	assets => \%assets,
	files => {
		'_views/default.html' => $view
	},
	config => {
		defaults => [
			{
				files => '/en',
				values => { lingua => 'en' },
			},
			{
				files => '/de',
				values => { lingua => 'de' },
			},
		]
	}
);

ok (Qgoda::CLI->new(['build'])->dispatch);

my ($rendered, $expected);

ok -e './_site/en/football/index.html';
$rendered = read_file './_site/en/football/index.html';
Encode::_utf8_on($rendered);
$expected = <<EOF;
/en/tennis/ (6)
/en/long-jump/ (3)
/en/fava/ (1)
EOF
chomp $expected;
is $rendered, $expected, '/en/football/';

ok -e './_site/de/fussball/index.html';
$rendered = read_file './_site/de/fussball/index.html';
Encode::_utf8_on($rendered);
$expected = <<EOF;
/de/tennis/ (6)
/de/weitsprung/ (3)
/de/fava/ (1)
EOF
chomp $expected;
is $rendered, $expected, '/de/fussball/';

ok -e './_site/en/tennis/index.html';
$rendered = read_file './_site/en/tennis/index.html';
Encode::_utf8_on($rendered);
$expected = <<EOF;
/en/football/ (6)
/en/long-jump/ (5)
EOF
chomp $expected;
is $rendered, $expected, '/en/tennis/';

ok -e './_site/de/tennis/index.html';
$rendered = read_file './_site/de/tennis/index.html';
Encode::_utf8_on($rendered);
$expected = <<EOF;
/de/fussball/ (6)
/de/weitsprung/ (5)
EOF
chomp $expected;
is $rendered, $expected, '/de/tennis/';

ok -e './_site/en/long-jump/index.html';
$rendered = read_file './_site/en/long-jump/index.html';
Encode::_utf8_on($rendered);
$expected = <<EOF;
/en/tennis/ (5)
/en/football/ (3)
EOF
chomp $expected;
is $rendered, $expected, '/en/long-jump/';

ok -e './_site/de/weitsprung/index.html';
$rendered = read_file './_site/de/weitsprung/index.html';
Encode::_utf8_on($rendered);
$expected = <<EOF;
/de/tennis/ (5)
/de/fussball/ (3)
EOF
chomp $expected;
is $rendered, $expected, '/de/weitsprung/';

ok -e './_site/en/fava/index.html';
$rendered = read_file './_site/en/fava/index.html';
Encode::_utf8_on($rendered);
$expected = <<EOF;
/en/football/ (1)
/en/long-jump/ (1)
/en/tennis/ (1)
EOF
chomp $expected;
is $rendered, $expected, '/en/fava/';

ok -e './_site/de/fava/index.html';
$rendered = read_file './_site/de/fava/index.html';
Encode::_utf8_on($rendered);
$expected = <<EOF;
/de/fussball/ (1)
/de/tennis/ (1)
/de/weitsprung/ (1)
EOF
chomp $expected;
is $rendered, $expected, '/de/fava/';

$site->tearDown;

done_testing;
