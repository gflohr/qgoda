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

my %assets;

$assets{"en/greeting.md"} = {
	title => "English Greeting",
	type => 'post',
	content => 'Good morning!',
	name => "greeting",
};
$assets{"de/begruessung.md"} = {
	title => "Deutsche Begrüßung",
	type => 'post',
	content => 'Guten Morgen!',
	name => "greeting",
};
$assets{"en/bye.md"} = {
	title => "English Bye",
	type => 'post',
	content => 'Good bye!',
	name => "bye",
};
$assets{"de/verabscheidung.md"} = {
	title => "Deutsche Verabschiedung",
	type => 'post',
	content => 'Tschüss!',
	name => "bye",
};
$assets{"en/about.md"} = {
	title => "About This Site",
	type => 'page',
	content => "It's about time!",
	name => "about",
};
$assets{"de/ueber.md"} = {
	title => "Über diese Site",
	type => 'page',
	content => 'Wurde ja auch Zeit!',
	name => "about",
};

my $links = <<EOF;
[%- USE q = Qgoda -%]
xref: [% q.xref('title', name = 'about' type = 'page' lingua = asset.lingua) %]

lxref: [% q.lxref('title', name = 'about' type = 'page') %]

xrefPost: [% q.xrefPost('title', name = 'greeting' lingua = asset.lingua) %]

broken xref: [% q.xref('title', name = 'gone' type = 'page' lingua = asset.lingua) %]

non-existing xref: [% q.xref('karma', name = 'about' type = 'page' lingua = asset.lingua) %]
EOF
$assets{"en/xref.md"} = {
	type => 'listing',
	content => $links,
	priority => -9999
};
$assets{"de/xref.md"} = {
	type => 'listing',
	content => $links,
	priority => -9999
};

my $site = TestSite->new(
	name => 'tpq-xref',
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
				files => '/de',
				values => { lingua => 'de' },
			},
		]
	}
);

ok (Qgoda::CLI->new(['build'])->dispatch);

ok -e "./_site/en/greeting/index.html";
ok -e "./_site/de/begruessung/index.html";
ok -e "./_site/en/about/index.html";
ok -e "./_site/de/ueber/index.html";
ok -e "./_site/en/xref/index.html";
ok -e "./_site/de/xref/index.html";

ok -e './_site/en/xref/index.html';
my $xref_en_content = read_file './_site/en/xref/index.html';
like $xref_en_content, qr{<p>xref: About This Site</p>}, 'xref en';
like $xref_en_content, qr{<p>lxref: About This Site</p>}, 'lxref en';
like $xref_en_content, qr{<p>xrefPost: English Greeting</p>}, 'xrefPost en';
like $xref_en_content, qr{<p>broken xref: </p>}, 'broken xref en';
like $xref_en_content, qr{<p>non-existing xref:</p>}, 'non-existing xref en';

ok -e './_site/de/xref/index.html';
my $xref_de_content = read_file './_site/de/xref/index.html';
Encode::_utf8_on($xref_de_content);
like $xref_de_content, qr{<p>xref: Über diese Site</p>}, 'xref de';
like $xref_de_content, qr{<p>lxref: Über diese Site</p>}, 'lxref de';
like $xref_de_content, qr{<p>xrefPost: Deutsche Begrüßung</p>}, 'xrefPost de';
like $xref_de_content, qr{<p>broken xref: </p>}, 'broken xref de';
like $xref_de_content, qr{<p>non-existing xref:</p>}, 'non-existing xref de';

$site->tearDown;

done_testing;
