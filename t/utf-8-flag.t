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

my $content = <<EOF;
<!--QGODA-NO-XGETTEXT-->[% USE q = Qgoda %]<!--/QGODA-NO-XGETTEXT-->

config.title: [% config.title %]

month: [% asset.month %]

full date: [% q.strftime('%B', -120067740, asset.lingua) %]

98.96 °F in the morning.
EOF

my $site = TestSite->new(name => 'utf-8-flag',
                         precious => ['*.mo', '*.po'],
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
                         });


ok (Qgoda::CLI->new(['build'])->dispatch);
ok -e '_site/en/index.html';
ok -e '_site/de/index.html';

$site->tearDown;

done_testing;
