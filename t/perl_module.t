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

use Test::More tests => 12;
use Qgoda::Util qw(perl_module);

ok perl_module 'foobar';
ok !perl_module '2foobar';
ok perl_module '_2foobar';
ok perl_module '_';
ok perl_module '__';

ok perl_module 'Foo::Bar';
# Valid Perl module name but we do not want to support it.
ok !perl_module "Foo'Bar";
ok !perl_module '2::Bar';
ok perl_module '_2::Bar';
ok perl_module '_::_';
ok perl_module '__::__';
ok perl_module 'Foo1::Bar2::Baz3';
