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
use Test::More;
use Locale::PO;

use Qgoda;
use Qgoda::CLI;

use TestSite;

my %assets;

$assets{'en/index.md'} = {
	name => 'master',
	content => 'translate me',
	tags => ['foo', 'bar'],
};
$assets{'de/index.md'} = {
	master => 'en/index.md',
	lingua => 'de',
};

my $site = TestSite->new(name => 'command-xgettext',
	assets => \%assets,
	config => {
		linguas => ['de'],
		defaults => [
			{
				files => '*.md',
				values => {
					translate => ['title', 'tags'],
				}
			},
			{
				files => 'en/**/*',
				values => {
					lingua => 'en',
				}
			},
			{
				files => 'de/**/*',
				values => {
					lingua => 'de',
				}
			},
		]
	},
	files => {
		'_po/MDPOTFILES' => "../en/index.md\n",
	}
);

ok chdir '_po', 'chdir';
ok (Qgoda::CLI->new([
	'xgettext',
	'--files-from', 'MDPOTFILES',
	'--output', 'messages.pot'])->dispatch, 'constructor');
my $entries = Locale::PO->load_file_ashash('messages.pot');
ok $entries, 'entries';

my $foo = $entries->{'"foo"'};
ok $foo, 'foo';
is $foo->msgctxt, '"tags"', 'msgctxt foo';

my $bar = $entries->{'"bar"'};
ok $bar, 'bar';
is $bar->msgctxt, '"tags"', 'msgctxt bar';

$site->tearDown;

done_testing;
