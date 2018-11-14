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

my $invalid = qr/^\[\% '' \%\]/;

ok -e '_site/array/index.html';
like ((read_file '_site/array/index.html'), $invalid, 'array filter');

ok -e '_site/scalar/index.html';
like ((read_file '_site/scalar/index.html'), $invalid, 'scalar filters');

ok -e '_site/scalar-ref/index.html';
like ((read_file '_site/scalar-ref/index.html'), $invalid, 'scalar ref filter');

$site->tearDown;

done_testing;