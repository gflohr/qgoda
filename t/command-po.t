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

use Qgoda::Util::Translate qw(get_masters);

# Do not just add 1 to the year.  That may not work on Feb, 29th.
my @next_year = localtime(time + 31556925);
my $next_year = sprintf('%04u-%02u-%02u',
                        1900 + $next_year[5], 1 + $next_year[4], $next_year[3]);

my $site = TestSite->new(
	name => 'command-po',
	config => {
		linguas => ['en', 'de']
	},
	assets => {
		'en-normal.md' => {
			lingua => 'en',
		},
		'en-draft.md' => {
			lingua => 'en',
			draft => 1
		},
		'en-future.md' => {
			lingua => 'en',
			date => $next_year
		},
		'de-normal.md' => {
			lingua => 'de',
			master => './en-normal.md',
		},
		'de-draft.md' => {
			lingua => 'de',
			master => './en-draft.md',
		},
		'de-future.md' => {
			lingua => 'de',
			master => './en-future.md',
		},
	}
);

# Check that all markdown documents are considered translatable, even future
# ones and drafts.
my %masters = get_masters;
ok $masters{'./en-normal.md'}, "Normal document should be translated.";
ok $masters{'./en-draft.md'}, "Draft should be translated.";
ok $masters{'./en-future.md'}, "Future document should be translated.";
ok ((3 == keys %masters), "There should be exactly 3 master documents.");

$site->tearDown;

done_testing;
