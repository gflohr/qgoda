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

use Test::More;
use JSON 2 qw(decode_json);

use Template;

my $vars = {
	data => {
		foo => 1,
		bar => 2,
		baz => 3
	}
};

my $tt = Template->new(
	PLUGIN_BASE => ['Qgoda::TT2::Plugin']
);

my ($json, $newlines, $round_trip, $template);

# We test that boolean options are basically supported.
$template = <<EOF;
[%- USE q = Qgoda -%]
[%- q.encodeJSON(data) -%]
EOF
ok $tt->process(\$template, $vars, \$json);
ok $json;
$round_trip = decode_json($json);
ok ref $round_trip;
is $round_trip->{foo}, 1;
is $round_trip->{bar}, 2;
is $round_trip->{baz}, 3;
$newlines = $json =~ y/\n/\n/;
is $newlines, 0;

# That that flags are honored.
$json = '';
$template = <<EOF;
[%- USE q = Qgoda -%]
[%- q.encodeJSON(data, 'pretty', 'canonical') -%]
EOF
ok $tt->process(\$template, $vars, \$json);
$json =~ s{[ \t]+}{}g;
my $expected = <<EOF;
{
"bar":2,
"baz":3,
"foo":1
}
EOF
is $json, $expected;

# Test that flags are disabled.
$json = '';
$template = <<EOF;
[%- USE q = Qgoda -%]
[%- q.encodeJSON(data, 'pretty', 'canonical', '-pretty') -%]
EOF
ok $tt->process(\$template, $vars, \$json);
$json =~ s{[ \t]+}{}g;
my $expected = '{"bar":2,"baz":3,"foo":1}';
is $json, $expected;

done_testing();
