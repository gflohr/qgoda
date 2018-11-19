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

BEGIN {
    my $test_dir = __FILE__;
    $test_dir =~ s/[-a-z0-9]+\.t$//i;
    unshift @INC, $test_dir;
}

use TestSite;
use Test::More;

use Cwd;
use POSIX (':sys_wait_h');
use Scalar::Util qw(blessed);
use AnyEvent;

use Qgoda::CLI;
use Qgoda::Util qw(read_file trim);

sub wait_for_timestamp();

my $site = TestSite->new(
	name => 'command-watch',
	assets => {
		'start.md' => {
			content => "initial\n",
		}
	},
	files => {
		'_views/default.html' => '[% asset.content %]'
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
my $phase = 0;
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

	ok 1, 'site built';

	my $expected = '<p>initial</p>';
	my $got = read_file '_site/start/index.html';

	is $got, $expected;

	Qgoda->new->stop("test finished");
}
