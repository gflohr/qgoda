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

use Test::More tests => 10;
use Qgoda::Util;

sub js_unescape($) { &Qgoda::Util::js_unescape };

is js_unescape "verbatim", "verbatim", "verbatim";
is js_unescape "\\tMakefile\\t", "\tMakefile\t", "one-character escapes";
is js_unescape "line 1 \\\nline 2", "line 1 line 2", "line continuation";
is js_unescape "null\\0byte", "null\000byte", "line continuation";
is js_unescape "\\157ctal", "157ctal", "octal not supported";
is js_unescape "x\\tx\\tx\\tx\\t", "x\tx\tx\tx\t", "multiple escapes";
is js_unescape "\\u0055nicode", "Unicode", "unicode escacpe sequences";
is js_unescape "\\u55nicode", "u55nicode", "invalid unicode escacpe sequences";
is js_unescape "\\x48exadecima\\x6c", "Hexadecimal", "hexadecimal esccpe sequences";
is js_unescape "\\x4Hexadecima\\x6c", "x4Hexadecimal", "invalid hexadecimal escacpe sequences";
