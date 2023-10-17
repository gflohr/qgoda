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

lxrefPost: [% q.lxrefPost('title', name = 'greeting') %]

existsXref: [% q.existsXref('title', name = 'about' type = 'page' lingua = asset.lingua) %]

lexistsXref: [% q.lexistsXref('title', name = 'about' type = 'page') %]

existsXrefPost: [% q.existsXrefPost('title', name = 'greeting' lingua = asset.lingua) %]

lexistsXrefPost: [% q.lexistsXrefPost('title', name = 'greeting') %]

broken xref: [% q.xref('title', name = 'gone' type = 'page' lingua = asset.lingua) %]

non-existing xref: [% q.xref('karma', name = 'about' type = 'page' lingua = asset.lingua) %]

ambiguous xref: [% q.existsXref('title', lingua = asset.lingua type= 'post') %]
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
like $xref_en_content, qr{<p>lxrefPost: English Greeting</p>}, 'lxrefPost en';
like $xref_en_content, qr{<p>existsXref: About This Site</p>}, 'existsXref en';
like $xref_en_content, qr{<p>lexistsXref: About This Site</p>}, 'lexistsXref en';
like $xref_en_content, qr{<p>existsXrefPost: English Greeting</p>}, 'existsXrefPost en';
like $xref_en_content, qr{<p>lexistsXrefPost: English Greeting</p>}, 'lexistsXrefPost en';
like $xref_en_content, qr{<p>broken xref: *</p>}, 'broken xref en';
like $xref_en_content, qr{<p>non-existing xref: *</p>}, 'non-existing xref en';
like $xref_en_content, qr{<p>ambiguous xref:[^<]+</p>}, 'ambiguous xref en';

ok -e './_site/de/xref/index.html';
my $xref_de_content = read_file './_site/de/xref/index.html';
Encode::_utf8_on($xref_de_content);
like $xref_de_content, qr{<p>xref: Über diese Site</p>}, 'xref de';
like $xref_de_content, qr{<p>lxref: Über diese Site</p>}, 'lxref de';
like $xref_de_content, qr{<p>xrefPost: Deutsche Begrüßung</p>}, 'xrefPost de';
like $xref_de_content, qr{<p>lxrefPost: Deutsche Begrüßung</p>}, 'lxrefPost de';
like $xref_de_content, qr{<p>broken xref: *</p>}, 'broken xref de';
like $xref_de_content, qr{<p>existsXref: Über diese Site</p>}, 'existsXref de';
like $xref_de_content, qr{<p>lexistsXref: Über diese Site</p>}, 'lexistsXref de';
like $xref_de_content, qr{<p>existsXrefPost: Deutsche Begrüßung</p>}, 'existsXrefPost de';
like $xref_de_content, qr{<p>lexistsXrefPost: Deutsche Begrüßung</p>}, 'lexistsXrefPost de';
like $xref_de_content, qr{<p>non-existing xref: *</p>}, 'non-existing xref de';
like $xref_de_content, qr{<p>ambiguous xref:[^<]+</p>}, 'ambiguous xref de';

$site->tearDown;

done_testing;
