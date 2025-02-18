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

use Test::More tests => 16;
use Qgoda::Util qw(qstrftime);
use POSIX();

sub mday2epoch($);

is qstrftime('%#', mday2epoch 1, "en"), "1st";
is qstrftime('%#', mday2epoch 2, "en"), "2nd";
is qstrftime('%#', mday2epoch 3, "en"), "3rd";
is qstrftime('%#', mday2epoch 11, "en"), "11th";
is qstrftime('%#', mday2epoch 12, "en"), "12th";
is qstrftime('%#', mday2epoch 13, "en"), "13th";
is qstrftime('%#', mday2epoch 21, "en"), "21st";
is qstrftime('%#', mday2epoch 22, "en"), "22nd";
is qstrftime('%#', mday2epoch 23, "en"), "23rd";
is qstrftime('%#', mday2epoch 1, "fr"), "1er";
is qstrftime('%#', mday2epoch 11, "fr"), "11";
is qstrftime('%#', mday2epoch 21 , "fr"), "21";
is qstrftime('%#', mday2epoch 13, "de"), "13.";
is qstrftime('%%# %%#', 2304), "%# %#";
is qstrftime('%#', mday2epoch 22, "en-US"), "22nd";
is qstrftime('%#', mday2epoch 1, "en", "hurz"), "1<hurz>st</hurz>";

sub mday2epoch($) {
    my ($mday) = @_;

    return POSIX::mktime(10, 11, 12, $mday, 4, 89);
}
