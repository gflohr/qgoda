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

use Test::More tests => 6;

use Qgoda::Util qw(globstar);

my $dir = __FILE__;
$dir =~ s{[-_a-zA-Z0-9.]+$}{globstar};
ok chdir $dir;

my @files = globstar '*.empty';
is_deeply [sort @files],
          [('one.empty', 'three.empty', 'two.empty')];

@files = globstar '**';
is_deeply [sort @files],
          [qw (
               first
               first/one.empty
               first/second
               first/second/one.empty
               first/second/third
               first/second/third/one.empty
               first/second/third/three.empty
               first/second/third/two.empty
               first/second/three.empty
               first/second/two.empty
               first/three.empty
               first/two.empty
               one.empty
               three.empty
               two.empty
              )];

@files = globstar '**/';
is_deeply [sort @files],
          [qw (
               first/
               first/second/
               first/second/third/
              )];

@files = globstar 'first/**';
is_deeply [sort @files],
          [qw (
               first/
               first/one.empty
               first/second
               first/second/one.empty
               first/second/third
               first/second/third/one.empty
               first/second/third/three.empty
               first/second/third/two.empty
               first/second/three.empty
               first/second/two.empty
               first/three.empty
               first/two.empty
              )];

@files = globstar 'first/**/';
is_deeply [sort @files],
          [qw (
               first/
               first/second/
               first/second/third/
              )];
