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
use MemStream;

my %config = (
	'pre-build' => [],
	'post-build' => [],
);

foreach my $count (0 .. 4) {
	push @{$config{'pre-build'}}, {
		name => "pre$count",
		run => $count % 2
			? "$^X build-task.pl build.log pre $count"
			: [$^X, 'build-task.pl', 'build.log', 'pre', $count],
	};
	push @{$config{'post-build'}}, {
		name => "post$count",
		run => $count % 2
			? "$^X build-task.pl build.log post $count"
			: [$^X, 'build-task.pl', 'build.log', 'post', $count],
	};
}

# Remove the build.log so that we can comment out the tear down step during
# development.
unlink 'build.log';

my $build_task = <<'EOF';
use strict;

my ($filename, $type, $count) = @ARGV;

open my $fh, '>>', $filename;
if ($ENV{QGODA_FAILURE_POST_4} && $count eq '4' && $type eq 'post') {
	exit 42;
} elsif ($ENV{QGODA_SIGNAL_POST_4} && $count eq '4' && $type eq 'post') {
	kill 9, $$;
	sleep 3;
} else {
	$fh->print("$type$count\n");
}
EOF

my $site = TestSite->new(
	name => 'command-build',
	config => \%config,
	assets => {
		'start.md' => {
			content => "initial\n",
		},
	},
	files => {
		'build-task.pl' => $build_task,
		'_views/default.html' => '[% asset.content %]'
	}
);

Qgoda::CLI->new(['build'])->dispatch;

my $expected = '<p>initial</p>';
my $got = read_file '_site/start/index.html';

is $got, $expected, 'normal file built';

# The log in the

# The log in the source directory also contains the post steps.
$got = read_file './build.log';
$expected = <<'EOF';
pre0
pre1
pre2
pre3
pre4
post0
post1
post2
post3
post4
EOF
is $got, $expected, 'build.log in source directory correct';

# The log in the _site directory only contains the pre steps.
$got = read_file './_site/build.log';
$expected = <<'EOF';
pre0
pre1
pre2
pre3
pre4
EOF
is $got, $expected, 'build.log in _site directory correct';

unlink 'build.log' or die $!;

my $stderr = tie *STDERR, 'MemStream';
$ENV{QGODA_FAILURE_POST_4} = 1;
Qgoda::CLI->new(['build'])->dispatch;
delete $ENV{QGODA_FAILURE_POST_4};
untie *STDERR;

# This time we expect a failure on the last task.
$got = read_file './build.log';
$expected = <<'EOF';
pre0
pre1
pre2
pre3
pre4
post0
post1
post2
post3
EOF
is $got, $expected, 'build.log after exit in source directory correct';

my @lines = split /\n/, $stderr->buffer;

is scalar @lines, 1, 'one line of error log for exit';
like $lines[0], qr/helper exited with code 42/, 'exit error message';

if ($^O eq 'MSWin32' || $^O eq 'cygwin') {
	skip 'signals not tested on MS-DOS', 1;
	ok 1;
} else {
	unlink 'build.log';

	$stderr = tie *STDERR, 'MemStream';
	$ENV{QGODA_SIGNAL_POST_4} = 1;
	Qgoda::CLI->new(['build'])->dispatch;
	delete $ENV{QGODA_SIGNAL_POST_4};
	untie *STDERR;

	# This time we expect a failure on the last task.
	$got = read_file './build.log';
	$expected = <<'EOF';
pre0
pre1
pre2
pre3
pre4
post0
post1
post2
post3
EOF
	is $got, $expected, 'build.log after singal in source directory correct';

	@lines = split /\n/, $stderr->buffer;

	is scalar @lines, 1, 'one line of error log for signal';
	like $lines[0], qr/helper terminated by signal 9/, 'signal message';
}

$site->tearDown;

done_testing;
