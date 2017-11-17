#! /usr/bin/env perl # -*- perl -*-

# Copyright (C) 2016 Guido Flohr <guido.flohr@cantanea.com>,
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

use Test::More;
use File::Globstar::ListMatch;

use Qgoda;
use Qgoda::Config;
use Qgoda::Util qw(collect_defaults);

my $q = Qgoda->new;

my ($path, $rules, $path, $expect, $got);

sub compile_rules($);

$rules = compile_rules [];
$expect = {};
$path = 'about-qgoda/index.md';
$got = collect_defaults $path, $rules;
is_deeply $got, $expect, 'empty input';

$rules = compile_rules [
    {
        files => 'index.md',
        values => {
            type => 'post',
            view => 'post.html',
        }
    },
    {
        files => 'index.html',
        values => {
            type => 'page',
        }
    }
];
$expect = {
    type => 'post',
    view => 'post.html',
};
$path = 'about-qgoda/index.md';
$got = collect_defaults $path, $rules;
is_deeply $got, $expect, 'empty input';

# Check that we are getting a deep copy of the default values.
my $original_rules = [
    {
        files => 'index.md',
        values => {
            type => 'post',
            view => 'post.html',
            deeply => {
                nested => 'original'
            }
        }
    },
];
$rules = compile_rules $original_rules;
$original_rules->[0]->{values}->{deeply}->{nested} => 'gotcha';
$expect = {
    type => 'post',
    view => 'post.html',
    deeply => {
        nested => 'original'
    }
};
$got = collect_defaults $path, $rules;
is_deeply $got, $expect, 'deep copy';

done_testing();

sub compile_rules($) {
    my $defaults = shift;

    $q->config->__compileDefaults($defaults);
}
