#! /usr/bin/env perl # -*- perl -*-

# Copyright (C) 2016-2020 Guido Flohr <guido.flohr@cantanea.com>,
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

use Test::More tests => 12;
use Qgoda::Util qw(perl_class);

ok perl_class 'foobar';
ok !perl_class '2foobar';
ok perl_class '_2foobar';
ok perl_class '_';
ok perl_class '__';

ok perl_class 'Foo::Bar';
# Valid Perl module name but we do not want to support it.
ok !perl_class "Foo'Bar";
ok !perl_class '2::Bar';
ok perl_class '_2::Bar';
ok perl_class '_::_';
ok perl_class '__::__';
ok perl_class 'Foo1::Bar2::Baz3';
