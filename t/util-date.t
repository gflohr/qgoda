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

BEGIN {
    my $test_dir = __FILE__;
    $test_dir =~ s/[-a-z0-9]+\.t$//i;
    unshift @INC, $test_dir;
}

use TestSite;
use Test::More;
use POSIX qw(strftime);
use Time::Local;

use Qgoda::Util::Date;

my $date = Qgoda::Util::Date->new('30 Oct 2018 16:52:34 UTC');
is $date->epoch, 1540918354;

my $epoch = 609314828;
$date = Qgoda::Util::Date->newFromEpoch($epoch);
is $date->epoch, $epoch;

my @then = localtime $date->epoch;

is $date->year, 1900 + $then[5];
is $date->month, sprintf '%02u', $date->imonth; 
is $date->imonth, 1 + $then[4]; 
is $date->mday, sprintf '%02u', $date->imday;
is $date->imday, $then[3];
is $date->day, $date->mday;
is $date->iday, $date->imday;
is $date->hour, sprintf '%02u', $date->hour;
is $date->ihour, $then[2];
is $date->hour12, sprintf '%02u', $date->ihour12;
is $date->ihour12, $then[2] % 12;
is $date->hour12, sprintf '%02u', $date->ihour12;
is $date->ihour12, $then[2] % 12;
is $date->ampm, strftime '%p', @then;
is $date->dst, $then[8] ? 'DST' : '';
is $date->wdayname, strftime '%A', @then;
is $date->awdayname, strftime '%a', @then;
is $date->monthname, strftime '%B', @then;
is $date->amonthname, strftime '%b', @then;
is $date->ISOString, '1989-04-23T06:07:08.000Z';
ok 0 < $date->cmpDate('1966-03-13T08:50:00.000Z');
is $date->cmpDate('1989-04-23T06:07:08.000Z'), 0;
ok 0 > $date->cmpDate('1966-03-13T08:50:00.000Z', 1);
ok 0 > $date->cmpDate('2018-10-30T16:52:34.000Z');
ok 0 < $date->cmpDate('2018-10-30T16:52:34.000Z', 1);
ok 0 < $date->ncmpDate($date->epoch - 1);
is $date->ncmpDate($date->epoch), 0;
ok 0 > $date->ncmpDate($date->epoch - 1, 1);
ok 0 > $date->ncmpDate($date->epoch + 1);
ok 0 < $date->ncmpDate($date->epoch + 1, 1);
my $copy = Qgoda::Util::Date->newFromEpoch($date->epoch);
ok $date->equals("$copy");
ok $date->nequals($copy);
is $date->rfc822, 'Sun, 23 Apr 1989 06:07:08 +0000';

# This is essentially the same code as in the tested module itself
# but there is no other portable way to get the timezone offset.
my $tz_offset = int ((Time::Local::timegm(@then) - $date->epoch) / 60);
my $tz = sprintf('%s%02u%02u',
                 $tz_offset < 0 ? '-' : '+',
                 $tz_offset / 60, $tz_offset % 60);
my @then_utc = localtime $date->epoch;
is $date->rfc822Local, strftime "%a, %d %b %Y %H:%M:%S $tz", @then_utc;
is $date->w3c, '1989-04-23';
is $date->w3cLocal, strftime '%Y-%m-%d', @then_utc;
is $date->w3cWithTime, '1989-04-23T06:07:08+0000';
is $date->w3cWithTimeLocal, strftime "%Y-%m-%dT%H:%M:%S$tz", @then_utc;
is $date->TO_JSON, $date->ISOString;

done_testing;
