#! /bin/false

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

package Qgoda::Util::Date;

use strict;

use Date::Parse qw(str2time);
use POSIX qw(strftime);
use Locale::TextDomain qw('qgoda');

use overload
    '""' => 'epoch',
    'eq' => 'equals',
    'cmp' => 'cmpDate',
    '==' => 'nequals',
    '<=>' => 'ncmpDate';

sub new {
    my ($class, $date) = @_;

    my $date = str2time $date;
    $date ||= 0;

    bless \$date, $class;
}

sub newFromEpoch {
    my ($class, $epoch) = @_;
    
    $epoch = time if !defined $epoch;
    my $self = $epoch;

    bless \$self, $class;
}

sub epoch {
    my ($self) = @_;

    return $$self;
}

sub year {
    my ($self) = @_;

    return 1900 + (localtime $$self)[5]
}

sub month {
    my ($self) = @_;

    return sprintf '%02u', 1 + (localtime $$self)[4]
}

sub imonth {
    my ($self) = @_;

    return 1 + (localtime $$self)[4]
}

sub mday {
    my ($self) = @_;

    return sprintf '%02u', (localtime $$self)[3]
}

sub imday {
    my ($self) = @_;

    return (localtime $$self)[3]
}

sub day {
    my ($self) = @_;

    return sprintf '%02u', (localtime $$self)[3]
}

sub iday {
    my ($self) = @_;

    return (localtime $$self)[3]
}

sub hour {
    my ($self) = @_;

    return sprintf '%02u', (localtime $$self)[2]
}

sub ihour {
    my ($self) = @_;

    return (localtime $$self)[2]
}

sub hour12 {
    my ($self) = @_;

    return sprintf '%02u', (localtime $$self)[2] % 12;
}

sub ihour12 {
    my ($self) = @_;

    return (localtime $$self)[2] % 12;
}

sub ampm {
    my ($self) = @_;

    return strftime '%p', localtime $$self;
}

sub dst {
    my ($self) = @_;

    # TRANSLATORS: This stands for "Daylight Savings Time".
    return (localtime $$self)[8] ? __"DST" : '';
}

sub wdayname {
    my ($self) = @_;

    return strftime '%A', localtime $$self;
}

sub awdayname {
    my ($self) = @_;

    return strftime '%a', localtime $$self;
}

sub monthname {
    my ($self) = @_;

    return strftime '%B', localtime $$self;
}

sub amonthname {
    my ($self) = @_;

    return strftime '%b', localtime $$self;
}

sub ISOString {
    my ($self) = @_;

    my @then = gmtime $$self;

    return sprintf '%04u-%02u-%02uT%02u:%02u:%02u.000Z',
        $then[5] + 1900, $then[4] + 1, $then[3],
        $then[2], $then[1], $then[0]
}

sub cmpDate {
    my ($self, $other, $swap) = @_;

    my $result = $self->ISOString cmp $other;
    $result = -$result if $swap;

    return $result;
}

sub ncmpDate {
    my ($self, $other, $swap) = @_;

    my $result = $self->epoch <=> $other;
    $result = -$result if $swap;

    return $result;
}

sub equals {
    my ($self, $other) = @_;

    return "$self" eq "$other";
}

sub nequals {
    my ($self, $other) = @_;

    return $$self == $other;
}

# Date and time in RFC822 format. For performance reasons, this is always
# in GMT.
sub rfc822 {
    my ($self) = @_;

    my @time = gmtime $$self;

    my @month_names = qw(Jan Feb Mar Apr May Jun
                         Jul Aug Sep Oct Nov Dec);
    my @day_names = qw(Sun Mon Tue Wed Thu Fri Sat Sun);

    return sprintf('%s, %02u %s %04u %02u:%02u:%02u +0000',
                   $day_names[$time[6]], $time[3], $month_names[$time[4]],
                   $time[5] + 1900, $time[2], $time[1], $time[0]);
}

# This is the same as rfc822() above but takes some effort to use the real
# timezone of the server. This is mostly a waste of time and not needed, see
# https://stackoverflow.com/a/52787169/5464233 for details.
sub rfc822_local {
    my ($self) = @_;

    my @time = localtime $$self;

    use integer;

    my $tz_offset = (Time::Local::timegm(@time) - $$self) / 60;
    my $tz = sprintf('%s%02u%02u',
                     $tz_offset < 0 ? '-' : '+',
                     $tz_offset / 60, $tz_offset % 60);

    my @month_names = qw(Jan Feb Mar Apr May Jun
                         Jul Aug Sep Oct Nov Dec);
    my @day_names = qw(Sun Mon Tue Wed Thu Fri Sat Sun);

    return sprintf('%s, %02u %s %04u %02u:%02u:%02u %s',
                   $day_names[$time[6]], $time[3], $month_names[$time[4]],
                   $time[5] + 1900, $time[2], $time[1], $time[0], $tz);
}

1;
