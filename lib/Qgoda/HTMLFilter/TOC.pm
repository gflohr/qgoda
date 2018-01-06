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

package Qgoda::HTMLFilter::TOC;

use strict;

use Qgoda;

use base qw(Qgoda::Processor);

sub new {
    my ($class, %args) = @_;

    my $from = exists $args{from} ? $args{from} : '<!--QGODA-CONTENT-->';
    my $to;
    if (exists $args{to}) {
        $to = $args{to};
    } else {
        $to = $from;
        if ($to !~ s{<!--}{<!--/}) {
            $to = '/' . $to;
        }
    }
    my $start = exists $args{start} ? $args{start} : 2;
    my $end = exists $args{end} ? $args{end} : 6;
    my $self = {
        __from => $from,
        __to => $to,
        __start => $start,
        __end => $end,
    };

    bless $self, $class;
}

sub start_document {
    my ($self, $chunk, %args) = @_;

    delete $self->{__active};

    return $chunk;
}

sub end_document {
    my ($self, $chunk, %args) = @_;

    delete $self->{__active};

    return $chunk;
}

sub comment {
    my ($self, $chunk, %args) = @_;

    if ($self->{__from} eq $args{text}) {
        $self->{__active} = 1;
    } elsif ($self->{__to} eq $args{text}) {
        $self->{__active} = 0;
    }

    return $chunk;
}

1;
