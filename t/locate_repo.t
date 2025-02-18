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

use Test::More;

use Qgoda::Repository;

my %repositories = (
    'git://github.com/gflohr/qgoda-site' => {
        type => 'Git',
        source => 'Github',
     },
    'git+ssh://example.com/foo/bar' => {
        type => 'Git',
        source => undef,
     },
    'git+http://github.com/gflohr/qgoda-site' => {
        type => 'Git',
        source => 'Github',
     },
    'git+https://github.com/gflohr/qgoda-site' => {
        type => 'Git',
        source => 'Github',
    },
    'git+file:///var/git/qgoda/fancy.git' => {
        type => 'Git',
    },
    'http://git.example.com/foo/bar.tar.gz' => {
        type => 'LWP',
    },
    'file:///path/to/directory' => {
        type => 'File',
    },
    'gflohr/qgoda-site' => {
        type => 'Git',
        source => 'Github',
    }
);

my @ids = sort keys %repositories;
foreach my $id (@ids) {
    my $repo = Qgoda::Repository->new($id);
    ok $repo, "construct $id";
    SKIP: {
        skip "$repo could not be built", 1 unless $repo;
        if ($repo) {
            is $repo->type, $repositories{$id}->{type}, "type of $id";
            is $repo->source, $repositories{$id}->{source}, "source of $id";
        }
    }
}

done_testing(3 * @ids);
