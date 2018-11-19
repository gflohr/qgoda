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

use Template;

use Test::More tests => 7;

my $assets = {
    strings => [
        { value => 'bazoo' },
        { value => 'bar' },
        { value => 'foo' },
        { value => 'Appleseed' },
        { value => 'John' },
        { value => 'Jane' },
        { value => 'baz' },
        { value => 'baz' },
        { value => 'Acme' },
        { value => 'Doe' },
    ],
    numbers => [
        { value => 48 },
        { value => 2304 },
        { value => 48 },
        { value => 13 },
        { value => 13 },
        { value => 12345679 },
    ],
    months => [
        {
            name => 'January',
            const => 'constant',
            date => {
                month => '01',
                imonth => 1,
            },
        },
        {
            name => 'February',
            const => 'constant',
            date => {
                month => '02',
                imonth => 2,
            },
        },
        {
            name => 'March',
            const => 'constant',
            date => {
                month => '03',
                imonth => 3,
            },
        },
        {
            name => 'April',
            const => 'constant',
            date => {
                month => '04',
                imonth => 4,
            },
        },
        {
            name => 'May',
            const => 'constant',
            date => {
                month => '05',
                imonth => 5,
            },
        },
        {
            name => 'June',
            const => 'constant',
            date => {
                month => '06',
                imonth => 6,
            },
        },
        {
            name => 'July',
            const => 'constant',
            date => {
                month => '07',
                imonth => 7,
            },
        },
        {
            name => 'August',
            const => 'constant',
            date => {
                month => '08',
                imonth => 8,
            },
        },
        {
            name => 'September',
            const => 'constant',
            date => {
                month => '09',
                imonth => 9,
            },
        },
        {
            name => 'October',
            const => 'constant',
            date => {
                month => '10',
                imonth => 10,
            },
        },
        {
            name => 'November',
            const => 'constant',
            date => {
                month => '11',
                imonth => 11,
            },
        },
        {
            name => 'December',
            const => 'constant',
            date => {
                month => '12',
                imonth => 12,
            },
        },
    ]
};

my $tt = Template->new;
my ($in, $out);

$out = '';
$in = <<EOF;
[%- USE Qgoda -%]
[%- FOREACH string IN strings.sortBy('value') %]
[%- string.value %]
[% END -%]
EOF
$tt->process(\$in, $assets, \$out) or die $tt->error;
is $out, <<EOF;
Acme
Appleseed
Doe
Jane
John
bar
baz
baz
bazoo
foo
EOF

$out = '';
$in = <<EOF;
[%- USE Qgoda -%]
[%- FOREACH number IN numbers.nsortBy('value') %]
[%- number.value %]
[% END -%]
EOF
$tt->process(\$in, $assets, \$out) or die $tt->error;
is $out, <<EOF;
13
13
48
48
2304
12345679
EOF

$out = '';
# We need the assignments to a and b to check whether the selection of an
# unused variable works.
$in = <<EOF;
[%- USE Qgoda -%]
[%- a = 1 %][% b = 2 -%]
[%- FOREACH month IN  months.sortBy('name') %]
[% month.name %]
[%- END -%]

EOF
$tt->process(\$in, $assets, \$out) or die $tt->error;
is $out, <<EOF;

April
August
December
February
January
July
June
March
May
November
October
September
EOF

$out = '';
$in = <<EOF;
[% USE Qgoda %]
[% FOREACH month IN  months.sortBy('date.imonth') %]
[%- month.name %]
[% END %]
EOF
$tt->process(\$in, $assets, \$out) or die $tt->error;
is $out, <<EOF;

January
October
November
December
February
March
April
May
June
July
August
September

EOF

$out = '';
$in = <<EOF;
[% USE Qgoda %]
[% FOREACH month IN  months.nsortBy('date.imonth') %]
[%- month.name %]
[% END %]
EOF
$tt->process(\$in, $assets, \$out) or die $tt->error;
is $out, <<EOF;

January
February
March
April
May
June
July
August
September
October
November
December

EOF

$out = '';
$in = <<EOF;
[% USE Qgoda %]
[% FOREACH month IN  months.sortBy('date.month') %]
[%- month.name %]
[% END %]
EOF
$tt->process(\$in, $assets, \$out) or die $tt->error;
is $out, <<EOF;

January
February
March
April
May
June
July
August
September
October
November
December

EOF

$out = '';
$in = <<EOF;
[% USE Qgoda %]
[% FOREACH month IN  months.sortBy('const', 'date.month') %]
[%- month.name %]
[% END %]
EOF
$tt->process(\$in, $assets, \$out) or die $tt->error;
is $out, <<EOF;

January
February
March
April
May
June
July
August
September
October
November
December

EOF
