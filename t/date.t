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

use Qgoda::Util::Date;

my $refdate = 1512072552;

sub refdate;

my ($date, $result);

$date = refdate;
eval { ++$date };
ok !$@, $@;
is $date->epoch, $refdate + 1, 'pre-increment';
isa_ok $date, 'Qgoda::Util::Date', 'pre-increment reference';

$date = refdate;
eval { $date++ };
ok !$@, $@;
is $date->epoch, $refdate + 1, 'post-increment';
isa_ok $date, 'Qgoda::Util::Date', 'post-increment reference';

$date = refdate;
eval { --$date };
ok !$@, $@;
is $date->epoch, $refdate - 1, 'pre-decrement';
isa_ok $date, 'Qgoda::Util::Date', 'pre-decrement reference';

$date = refdate;
eval { $date-- };
ok !$@, $@;
is $date->epoch, $refdate - 1, 'post-decrement';
isa_ok $date, 'Qgoda::Util::Date', 'post-decrement reference';

$date = refdate;
eval { $result = !$date };
ok !$@, $@;
is $result, !$refdate, 'logical not';
isa_ok $date, 'Qgoda::Util::Date', 'logical not reference';

$date = refdate;
eval { $result = ~$date };
ok !$@, $@;
is $result, ~$refdate, 'bitwise not';
isa_ok $date, 'Qgoda::Util::Date', 'bitwise not reference';

done_testing();

sub refdate {
    Qgoda::Util::Date->newFromEpoch($refdate);
}
