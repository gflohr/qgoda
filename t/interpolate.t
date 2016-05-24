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

use Test::More tests => 2;
use Qgoda::Util qw(interpolate);

my $data = {
    answer => 42,
};

is interpolate("verbatim", $data), "verbatim", "verbatim";
is interpolate("The answer is {answer}.", $data), "The answer is 42.", "simple";
is interpolate("The answer is {answer} because it's always {answer}.", $data), 
    "The answer is 42 because it's always 42.", "multiple";
