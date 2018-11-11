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
	title => "English Post",
	type => 'post',
	content => 'Good morning!',
	name => "greeting",
};
$assets{"de/begruessung.md"} = {
	title => "Deutsches posting",
	type => 'post',
	content => 'Guten Morgen!',
	name => "greeting",
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
link: [% q.link(name = 'about' type = 'page' lingua = asset.lingua) %]

llink: [% q.llink(name = 'about' type = 'page') %]

linkPost: [% q.linkPost(name = 'greeting' lingua = asset.lingua) %]

llinkPost: [% q.llinkPost(name = 'greeting') %]
EOF
$assets{"en/links.md"} = {
	type => 'listing',
	content => $links,
	priority => -9999
};
$assets{"de/links.md"} = {
	type => 'listing',
	content => $links,
	priority => -9999
};

my $site = TestSite->new(
	name => 'tgp-links',
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
ok -e "./_site/en/links/index.html";
ok -e "./_site/de/links/index.html";

ok -e './_site/en/links/index.html';
my $links_en_content = read_file './_site/en/links/index.html';
like $links_en_content, qr{<p>link: /en/about/</p>}, 'link en';
like $links_en_content, qr{<p>llink: /en/about/</p>}, 'llink en';
like $links_en_content, qr{<p>linkPost: /en/greeting/</p>}, 'linkPost en';
like $links_en_content, qr{<p>llinkPost: /en/greeting/</p>}, 'llinkPost en';

ok -e './_site/de/links/index.html';
my $links_en_content = read_file './_site/de/links/index.html';
like $links_en_content, qr{<p>link: /de/ueber/</p>}, 'link en';
like $links_en_content, qr{<p>llink: /de/ueber/</p>}, 'llink en';
like $links_en_content, qr{<p>linkPost: /de/begruessung/</p>}, 'linkPost en';
like $links_en_content, qr{<p>llinkPost: /de/begruessung/</p>}, 'llinkPost en';

$site->tearDown;

done_testing;
