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
use Encode;
use utf8;

use Qgoda::Util qw(read_file);
use Qgoda::CLI;

my $content = <<EOF;
<!--qgoda-no-xgettext-->[% USE q = Qgoda %]<!--/qgoda-no-xgettext-->

config.title: [% config.title %]

month: [% asset.month %]

full date: [% q.strftime('%B', -120067740, asset.lingua) %]

98.96 °F in the morning.
EOF

my $title = 'Lots of €€';
Encode::_utf8_on($title);
my $site = TestSite->new(name => 'utf-8-flag',
                         precious => ['*.mo', '*.po'],
                         config => {
                             title => $title,
                             linguas => ['en', 'de'],
                             po => {
                                 textdomain => 'messages',
                             },
                             exclude => ['/LocaleData'],
                         },
                         assets => {
                             'en/index.md' => {
                                 location => '/en/index.html',
                                 month => 'March',
                                 lingua => 'de',
                                 title => 'Hello, world!',
                                 content => $content,
                             },
                             'de/index.md' => {
                                 location => '/de/index.html',
                                 main => '/en/index.md',
                                 lingua => 'de',
                                 translate => ['month', 'title']
                             }
                         });


ok (Qgoda::CLI->new(['build'])->dispatch);
ok -e '_site/en/index.html';
ok -e '_site/de/index.html';

my $html = read_file '_site/de/index.html' or die;
Encode::_utf8_on($html);

ok $html =~ m{<title>Hallo, Welt!</title>};
ok $html =~ m{<h1>Hallo, Welt!</h1>};
ok $html =~ m{<p>config.title: Lots of €€</p>};
if ($ENV{AUTHOR_TESTING}) {
    # Requires a German locale being installed.
    ok $html =~ m{<p>month: März</p>};
    ok $html =~ m{<p>full date: März</p>};
}
ok $html =~ m{<p>37,2 °C am Morgen.</p>};

$site->tearDown;

done_testing;
