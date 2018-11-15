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

use Qgoda::CLI;
use Qgoda::Util qw(read_file);

my %assets;

my $array_filter = <<EOF;
[% USE q = Qgoda %]
[% q.list(['name', 'foobar']) %]
EOF
$assets{'array.md'} = {
	content => $array_filter
};

my $scalar_filter = <<EOF;
[% USE q = Qgoda %]
[% q.list('foobar') %]
EOF
$assets{'scalar.md'} = {
	content => $scalar_filter
};

my $scalar_ref_filter = <<EOF;
[% USE q = Qgoda %]
[% q.list(asset.date) %]
EOF
$assets{'scalar-ref.md'} = {
	content => $scalar_ref_filter
};

$assets{'bl.md'} = {
	number => 6,
	string => 'beer',
	array => ['beer', 'wine'],
	type => 'filter',
};
$assets{'cl.md'} = {
	number => 48,
	string => 'root',
	array => ['root', 'math', 'listen'],
	type => 'filter',
};
$assets{'gl.md'} = {
	number => '13',
	string => 'tree',
	array => ['tree', 'nature', 'power'],
	type => 'filter',
};
$assets{'yl.md'} = {
	number => 2304,
	string => 'strawberry',
	array => ['strawberry', 'soft', 'beautiful'],
	type => 'filter',
};
$assets{'bu.md'} = {
	number => 6,
	string => 'Beer',
	array => ['Beer', 'Wine'],
	type => 'filter',
};
$assets{'cu.md'} = {
	number => 48,
	string => 'Root',
	array => ['Root', 'Math', 'Listen'],
	type => 'filter',
};
$assets{'gu.md'} = {
	number => '13',
	string => 'Tree',
	array => ['Tree', 'Nature', 'Power'],
	type => 'filter',
};
$assets{'yu.md'} = {
	number => 2304,
	string => 'StrawBerry',
	array => ['StrawBerry', 'Soft', 'Beautiful'],
	type => 'filter',
};

my $filters = <<'EOF';
[% USE q = Qgoda %]

default: [% q.list(string = 'strawberry').vmap('relpath').sort.join(':') %]

eq: [% q.list(string = ['eq', 'StrawBerry']).vmap('relpath').sort.join(':') %]

ne: [% q.list(string = ['ne', 'beer'], type = 'filter').vmap('relpath').sort.join(':') %]

ge: [% q.list(string = ['ge', 'beer']).vmap('relpath').sort.join(':') %]
EOF
$assets{'filters.md'} = {
	content => $filters,
};

my $site = TestSite->new(
	name => 'tpq-include',
	assets => \%assets,
	files => {
		'_views/default.html' => "[% asset.content %]",
	}
);

# Temporarily close stderr while building the site.
open my $olderr, '>&STDERR' or die "cannot dup stderr: $!";
close STDERR;
ok(Qgoda::CLI->new(['build'])->dispatch);
open STDERR, '>&', $olderr;

is (scalar $site->findArtefacts, 12);

ok -e '_site/filters/index.html';
my $filters_result = read_file '_site/filters/index.html';

like $filters_result, qr{<p>default: yl.md</p>}, 'default filter';
like $filters_result, qr{<p>eq: yu.md</p>}, 'eq filter';
like $filters_result,
     qr{<p>ne: bu.md:cl.md:cu.md:gl.md:gu.md:yl.md:yu.md</p>},
     'ne filter';
like $filters_result,
     qr{<p>ge: bl.md:cl.md:gl.md:yl.md</p>},
     'ge filter';

my $invalid = qr/^\[\% '' \%\]/;

ok -e '_site/array/index.html';
like ((read_file '_site/array/index.html'), $invalid, 'array filter');

ok -e '_site/scalar/index.html';
like ((read_file '_site/scalar/index.html'), $invalid, 'scalar filters');

ok -e '_site/scalar-ref/index.html';
like ((read_file '_site/scalar-ref/index.html'), $invalid, 'scalar ref filter');

$site->tearDown;

done_testing;