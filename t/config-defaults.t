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

use strict;

BEGIN {
    my $test_dir = __FILE__;
    $test_dir =~ s/[-a-z0-9]+\.t$//i;
    unshift @INC, $test_dir;
}

use TestSite;
use Test::More;

use Qgoda::Config;
use Qgoda::Schema;
use Storable qw(dclone);

use constant true => $JSON::PP::true;
use constant false => $JSON::PP::false;

my ($site, $got, $expected);

my $expected = {
	plugins => '_plug-ins',
	po => '_po',
	timestamp => '_timestamp',
	views => '_views'
};

$site = TestSite->new(name => 'config-defaults',
	config => {
		paths => {
			plugins => '_plug-ins'
		}
	}
);
$got = Qgoda->new->config->{paths};
delete $got->{site};
is_deeply $got, $expected, 'replace simple key in top-level object';
$site->tearDown;

my $schema = Qgoda::Schema->config->{properties}->{processors}->{properties};
$expected = {
	chains => dclone($schema->{chains}->{default}),
	options => dclone($schema->{options}->{default}),
	triggers => dclone($schema->{triggers}->{default}),
};
$expected->{options}->{HTMLFilter}->{TOC}->{start} = 3;
$site = TestSite->new(name => 'config-defaults',
	config => {
		processors => {
			options => {
				HTMLFilter => {
					TOC => {
						# This is normally 2.
						start => 3
					}
				}
			}
		}
	}
);
$got = Qgoda->new->config->{processors};
is_deeply $got, $expected, 'individually overwrite deeply nested property';

#$site->tearDown;

done_testing;
