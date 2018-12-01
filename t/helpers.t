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

my $config = <<'EOF';
	helpers:
		dummy: ['perl', '_script.pl']
EOF
$config =~ s/\t/  /g;

my $script = <<'EOF';
open my $fh, '>', '_perl_works';
while (1) { sleep 1 }
EOF

my $site = TestSite->new(
	name => 'helpers',
	assets => {
		'start.md' => {
			content => "initial\n",
		}
	},
	files => {
		'_views/default.html' => '[% asset.content %]',
		'_config.yaml' => $config,
		'_script.pl' => $script,
	}
);

my $watcher = AnyEvent->timer(
	after => 3,
	cb => sub {
		ok 0, "test did not finish after 3 seconds";
		Qgoda->new->stop("test did not finish after 3 seconds")
	},
);

my $timestamp;
my $w = AnyEvent->timer(
	after => 0.1,
	interval => 0.1,
	cb => \&wait_for_change,
);

Qgoda::CLI->new(['watch'])->dispatch;

$site->tearDown;

done_testing;

sub wait_for_change() {
	return if !-e '_timestamp';

	$timestamp = read_file '_timestamp';
	trim $timestamp;
	# Safe-guard against incomplete writes.
	return if $timestamp > time;

	undef $w;

	ok 1, 'site built';

	my $expected = '<p>initial</p>';
	my $got = read_file '_site/start/index.html';

	is $got, $expected;
	$w = AnyEvent->timer(
		after => 0.1,
		interval => 0.1,
		cb => \&wait_for_perl,
	);
}

sub wait_for_perl {
	return if !-e '_perl_works';

	Qgoda->new->stop("test finished");
}
