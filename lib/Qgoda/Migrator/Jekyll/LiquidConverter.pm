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

package Qgoda::Migrator::Jekyll::LiquidConverter;

use strict;

use Locale::TextDomain qw(com.cantanea.qgoda);

use Qgoda;

sub new {
    my ($class, $filename, $code, %options) = @_;

    $options{tt2_open} ||= '[%';
    $options{tt2_close} ||= '%]';
    $options{offset} ||= 1;

    bless {
        __filename => $filename,
        __code => $code,
        __options => { %options },
    }, $class;
}

sub convert {
    my ($self) = @_;

    my $code = $self->{__code};
    $self->{__lineno} = 1 + $self->{__options}->{offset};
    my ($open, $close) = ('[%', '%]');

    my $output = '';
    while ($code =~ s/^(.*?)(\{\{|\{%|\n)//) {
        $output .= $1;
        if ('{{' eq $1) {
            $output .= $open;
        } elsif ('{%' eq $1) {
            $output .= $open;
        } else {
            $output .= $2;
            ++$self->{__options}->{lineno};
        }
    }
    
    $output .= $code if length $code;

    return $output;
}

1;