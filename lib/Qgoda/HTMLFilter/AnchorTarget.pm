#! /bin/false

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

package Qgoda::HTMLFilter::AnchorTarget;

use strict;

use Qgoda::Util qw(empty);

sub new {
    my ($class, %args) = @_;

    my $match = $args{match};
    $match = '^(?:https?|ftp)://' if empty $match;

    my $target = $args{target};
    $target = '_blank' if empty $target;

    $match = qr/$match/;
    my $self = {
        __match => $match,
        __target => $target,
    };

    bless $self, $class;
}

sub start {
    my ($self, $chunk, %args) = @_;

    return $chunk if 'a' ne $args{tagname};

    my $attr = $args{attr};
    my $href = $args{attr}->{href};

    return $chunk if empty $href;
    return $chunk if !empty $attr->{target};
    return $chunk if $href !~ $self->{__match};

    my $attrseq = $args{attrseq};
    push @$attrseq, 'target';
    $attr->{target} = $self->{__target};

    $chunk = '<' . $args{tagname};

    foreach my $key (@$attrseq) {
        my $value = $attr->{$key};

        my %escapes = (
            '"' => '&quot;',
            '&' => '&amp;'
        );
        $value =~ s/(["&])/$escapes{$1}/g;
        $chunk .= qq{ $key="$value"};
    }
    
    $chunk .= '>';

    return $chunk;
}
1;
