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
anchor: [% q.anchor(name = 'about' type = 'page' lingua = asset.lingua) %]

lanchor: [% q.lanchor(name = 'about' type = 'page') %]

anchorPost: [% q.anchorPost(name = 'greeting' lingua = asset.lingua) %]

lanchorPost: [% q.lanchorPost(name = 'greeting') %]

existsAnchor: [% q.existsAnchor(name = 'about' type = 'page' lingua = asset.lingua) %]

lexistsAnchor: [% q.lexistsAnchor(name = 'about' type = 'page') %]

existsAnchorPost: [% q.existsAnchorPost(name = 'greeting' lingua = asset.lingua) %]

lexistsAnchorPost: [% q.lexistsAnchorPost(name = 'greeting') %]

existsAnchor broken: [% q.existsAnchor(name = 'aboud' type = 'page' lingua = asset.lingua) %]

lexistsAnchor broken: [% q.lexistsAnchor(name = 'aboud' type = 'page') %]

existsAnchorPost broken: [% q.existsAnchorPost(name = 'greetink' lingua = asset.lingua) %]

lexistsAnchorPost broken: [% q.lexistsAnchorPost(name = 'greetink') %]

broken anchor: [% q.anchor(name = 'gone' type = 'page' lingua = asset.lingua) %]

ambiguous anchor: [% q.anchor(lingua = asset.lingua) %]
EOF
$assets{"en/anchor.md"} = {
	type => 'listing',
	content => $links,
	priority => -9999
};
$assets{"de/anchor.md"} = {
	type => 'listing',
	content => $links,
	priority => -9999
};

my $site = TestSite->new(
	name => 'tpq-anchor',
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
ok -e "./_site/en/anchor/index.html";
ok -e "./_site/de/anchor/index.html";

ok -e './_site/en/anchor/index.html';
my $anchor_en_content = read_file './_site/en/anchor/index.html';
like $anchor_en_content,
     qr{<p>anchor: <a href="/en/about/">About This Site</a></p>},
	 'anchor en';
like $anchor_en_content,
     qr{<p>lanchor: <a href="/en/about/">About This Site</a></p>},
	 'lanchor en';
like $anchor_en_content,
     qr{<p>anchorPost: <a href="/en/greeting/">English Greeting</a></p>},
	 'anchorPost en';
like $anchor_en_content,
     qr{<p>lanchorPost: <a href="/en/greeting/">English Greeting</a></p>},
	 'lanchorPost en';
like $anchor_en_content,
     qr{<p>existsAnchor: <a href="/en/about/">About This Site</a></p>},
	 'existsAnchor en';
like $anchor_en_content,
     qr{<p>lexistsAnchor: <a href="/en/about/">About This Site</a></p>},
	 'lexistsAnchor en';
like $anchor_en_content,
     qr{<p>existsAnchorPost: <a href="/en/greeting/">English Greeting</a></p>},
	 'existsAnchorPost en';
like $anchor_en_content,
     qr{<p>lexistsAnchorPost: <a href="/en/greeting/">English Greeting</a></p>},
	 'lexistsAnchorPost en';
like $anchor_en_content,
     qr{<p>existsAnchor broken: </p>},
	 'existsAnchor broken en';
like $anchor_en_content,
     qr{<p>lexistsAnchor broken: </p>},
	 'lexistsAnchor broken en';
like $anchor_en_content,
     qr{<p>existsAnchorPost broken: </p>},
	 'existsAnchorPost broken en';
like $anchor_en_content,
     qr{<p>lexistsAnchorPost broken: </p>},
	 'lexistsAnchorPost broken en';
like $anchor_en_content,
     qr{<p>broken anchor: </p>},
	 'broken anchor en';
like $anchor_en_content,
     qr{<p>ambiguous anchor: <a href="[^"]+">.+</p>},
	 'ambiguous anchor en';

ok -e './_site/de/anchor/index.html';
my $anchor_de_content = read_file './_site/de/anchor/index.html';
Encode::_utf8_on($anchor_de_content);
like $anchor_de_content,  
     qr{<p>anchor: <a href="/de/ueber/">Über diese Site</a></p>},
	 'anchor de';
like $anchor_de_content,
     qr{<p>lanchor: <a href="/de/ueber/">Über diese Site</a></p>},
	 'lanchor de';
like $anchor_de_content,
     qr{<p>anchorPost: <a href="/de/begruessung/">Deutsche Begrüßung</a></p>},
	 'anchorPost de';
like $anchor_de_content,
     qr{<p>lanchorPost: <a href="/de/begruessung/">Deutsche Begrüßung</a></p>},
	 'lanchorPost de';
like $anchor_de_content,
     qr{<p>existsAnchor: <a href="/de/ueber/">Über diese Site</a></p>},
	 'existsAnchor de';
like $anchor_de_content,
     qr{<p>lexistsAnchor: <a href="/de/ueber/">Über diese Site</a></p>},
	 'lexistsAnchor de';
like $anchor_de_content,
     qr{<p>existsAnchorPost: <a href="/de/begruessung/">Deutsche Begrüßung</a></p>},
	 'existsAnchorPost de';
like $anchor_de_content,
     qr{<p>lexistsAnchorPost: <a href="/de/begruessung/">Deutsche Begrüßung</a></p>},
	 'lexistsAnchorPost de';
like $anchor_de_content,
     qr{<p>existsAnchor broken: </p>},
	 'existsAnchor broken de';
like $anchor_de_content,
     qr{<p>lexistsAnchor broken: </p>},
	 'lexistsAnchor broken de';
like $anchor_de_content,
     qr{<p>existsAnchorPost broken: </p>},
	 'existsAnchorPost broken de';
like $anchor_de_content,
     qr{<p>lexistsAnchorPost broken: </p>},
	 'lexistsAnchorPost broken de';
like $anchor_de_content,
     qr{<p>broken anchor: </p>},
	 'broken anchor de';
like $anchor_de_content,
     qr{<p>ambiguous anchor: <a href="[^"]+">.+</p>},
	 'ambiguous anchor de';

$site->tearDown;

done_testing;
