#! /usr/bin/env perl # -*- perl -*-

# Copyright (C) 2016 Guido Flohr <guido.flohr@cantanea.com>,
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

my $po = <<EOF;
msgid ""
msgstr ""
"Content-Type: text/plain; charset=UTF-8\\n"

msgctxt "month"
msgid "March"
msgstr "März"

msgctxt "title"
msgid "Hello, world!"
msgstr "Hallo, Welt!"

msgid "98.96 °F in the morning."
msgstr "37,2 °C am Morgen."
EOF

my $content = <<EOF;
98.96 °F in the morning.
EOF

my $site = TestSite->new(name => 'utf-8-flag',
                         precious => ['*.mo'],
                         config => {
                             title => 'Lots of €€',
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
                                 master => '/en/index.md',
                                 lingua => 'de',
                                 translate => ['month', 'title']
                             }
                         },
                         files => {
                             '_po/de.po' => $po,
                         });


ok (Qgoda::CLI->new(['po', 'potfiles'])->dispatch);
ok (Qgoda::CLI->new(['build'])->dispatch);
ok -e '_site/en/index.html';
ok -e '_site/de/index.html';

#$site->tearDown;

done_testing;
