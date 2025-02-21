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

use Cwd;
use POSIX (':sys_wait_h');
use Scalar::Util qw(blessed);
use AnyEvent;

use Qgoda::CLI;
use Qgoda::Util qw(read_file trim);

sub wait_for_timestamp();

my %config = (
	'pre-build' => [],
	'post-build' => [],
);

foreach (0 .. 9) {
	push @{$config{'pre-build'}}, {
		name => "pre$_",
		run => qq{perl -e 'open my \$fh, ">>", "build.log" or die \$!; print \$fh "pre$_\n";'},
	};
	push @{$config{'post-build'}}, {
		name => "post$_",
		run => qq{perl -e 'open my \$fh, ">>", "build.log" or die \$!; print \$fh "post$_\n";'},
	};
}

my $site = TestSite->new(
	name => 'command-build',
	config => \%config,
	assets => {
		'start.md' => {
			content => "initial\n",
		}
	},
	files => {
		'_views/default.html' => '[% asset.content %]'
	}
);

Qgoda::CLI->new(['build'])->dispatch;

my $expected = '<p>initial</p>';
my $got = read_file '_site/start/index.html';

is $got, $expected;

# The log in the output directory only contains the pre steps
$got = read_file './build.log';
$expected = <<"EOF";
pre0
pre1
pre2
pre3
pre4
pre5
pre6
pre7
pre8
pre9
EOF
is $got, $expected, 'build.log in _site directory incorrect';

# The log in the source directory also contains the post steps.
$got = read_file './build.log';
$expected = <<"EOF";
pre0
pre1
pre2
pre3
pre4
pre5
pre6
pre7
pre8
pre9
post0
post1
post2
post3
post4
post5
post6
post7
post8
post9
EOF
is $got, $expected, 'build.log in source directory incorrect';

$site->tearDown;

done_testing;
