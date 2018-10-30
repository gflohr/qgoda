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

use Test::More;
use Qgoda::Util qw(tt2_args_merge);

my @args = qw(foo bar);
my %conf = (foo => 1, bar => 2);

my ($args, $conf) = tt2_args_merge \@args, \%conf, ['baz'], { baz => 3};

is_deeply $args, [qw(foo bar baz)];
is_deeply $conf, { foo => 1, bar => 2, baz => 3};

($args, $conf) = tt2_args_merge \@args, \%conf, ['-bar'], { foo => 2304};

is_deeply $args, [qw(foo)];
is_deeply $conf, { foo => 2304, bar => 2 };

done_testing;
