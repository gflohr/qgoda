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
use Storable qw(freeze thaw);

use Qgoda::CLI;

my $hello_js = "console.log('Hello, world!')\n";
my $echo_js = "console.log(__perl__.input)\n";
my $return_js = "__perl__.return = 'Hello, world!'";
my $input_json = qq{{"foo":"bar"}};
my $input_yaml = <<EOF;
---
foo: 'bar'
EOF
my $input_pm = <<'EOF';
$VAR1 = {
          'foo' => 'bar'
        };
EOF
my $input_storable = freeze { foo => 'bar' };

my $site = TestSite->new(name => 'command-javascript',
                         files => {
                             'hello.js' => $hello_js,
                             'echo.js' => $echo_js,
							 'return.js' => $return_js,
                             'input.json' => $input_json,
                             'input.yaml' => $input_yaml,
                             'input.pm' => $input_pm,
                             'input.storable' => $input_storable
                         });

ok -e './hello.js';
ok -e './echo.js';
ok -e './return.js';
ok -e './input.json';
ok -e './input.yaml';
ok -e './input.pm';
ok -e './input.storable';

my $stdout;

ok (Qgoda::CLI->new(['js', '--no-output', './hello.js'])->dispatch);
$stdout = Qgoda->new->jsout;
is $stdout, "Hello, world!\n";

ok (Qgoda::CLI->new(['js',
                     '--no-output',
                     '--input', './input.json',
                     './echo.js'])->dispatch);
$stdout = Qgoda->new->jsout;
is $stdout, "{foo: 'bar'}\n";

# Lower case format.
ok (Qgoda::CLI->new(['js',
                     '--no-output',
                     '--input-format', 'json',
                     '--input', './input.json',
                     './echo.js'])->dispatch);
$stdout = Qgoda->new->jsout;
is $stdout, "{foo: 'bar'}\n";

ok (Qgoda::CLI->new(['js',
                     '--no-output',
                     '--input-format', 'JSON',
                     '--input-data', $input_json, 
                     './echo.js'])->dispatch);
$stdout = Qgoda->new->jsout;
is $stdout, "{foo: 'bar'}\n";

ok (Qgoda::CLI->new(['js',
                     '--no-output',
                     './return.js'])->dispatch);
my $jsreturn= Qgoda->new->jsreturn;
is $jsreturn, 'Hello, world!';

$site->tearDown;

done_testing;
