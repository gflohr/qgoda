#! /bin/false

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

package Qgoda::Util::Date;

use strict;

use Date::Parse qw(str2time);
use POSIX qw(strftime);
use Locale::TextDomain qw('com.cantanea.qgoda');

use overload
    '""' => 'toString';

sub new {
    my ($class, $date) = @_;

    my $date = str2time $date;
    $date ||= 0;

    bless \$date, $class;
}

sub epoch {
    my ($self) = @_;

    return $$self;
}

sub toString {
    return 'a stringified date';
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
1;
