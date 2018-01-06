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
use Qgoda::Util qw(html_escape slugify);

use base qw(Qgoda::Processor);

sub new {
    my ($class, %args) = @_;

    # FIXME! Use tags instead, for example <qgoda-content>.
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

    my $root = $self->__deepen($self->{__items});

    return $chunk;
}

sub comment {
    my ($self, $chunk, %args) = @_;

    if ($self->{__from} eq $args{text}) {
        $self->{__active} = 1;
        $self->{__headlines} = [];
        $self->{__slugs} = {};
        $self->{__items} = [];
        $self->{__path} = [0];
    } elsif ($self->{__to} eq $args{text}) {
        $self->{__active} = 0;
    }

    return $chunk;
}

sub start {
    my ($self, $chunk, %args) = @_;

    return $chunk if !$self->{__active};

    return $chunk if $args{tagname} !~ /^h([[1-9][0-9]*)$/;
    my $level = $1;
    return $chunk if $level < $self->{__start};
    return $chunk if $level > $self->{__end};

    $chunk .= '<qgoda-toc-marker />';

    return $chunk;
}

sub end {
    my ($self, $chunk, %args) = @_;

    return $chunk if !$self->{__active};

    return $chunk if $args{tagname} !~ /^h([[1-9][0-9]*)$/;
    my $hlevel = $1;
    return $chunk if $hlevel < $self->{__start};
    return $chunk if $hlevel > $self->{__end};

    return $chunk if ${$args{output}} !~ s{<qgoda-toc-marker />(.*)}{}s;
    my $text = $1;
    my $level = $hlevel - $self->{__start} + 1;
    my $depth = @{$self->{__path}};

    my $valid = 1;
    if ($depth > $level) {
        foreach ($level .. $depth - 1) {
            pop @{$self->{__path}};
        }
        ++$self->{__path}->[-1];
    } elsif ($depth + 1 == $level) {
        push @{$self->{__path}}, 1;
    } elsif ($depth == $level) {
        ++$self->{__path}->[-1];
    } else {
        undef $valid;
    }

    if ($valid) {
        my $slug = $text;
        $slug =~ s{<.*?>}{}s;
        $slug = html_escape slugify $slug;
        while ($self->{__slugs}->{$slug}) {
            $slug .= '-';
        }
        $self->{__slugs}->{$slug} = 1;
        
        ${$args{output}} .= qq{<a href="#" name="$slug" id="$slug"></a>};
        push @{$self->{__items}}, {
           slug => $slug,
           path => [@{$self->{__path}}],
           text => $text
        };
    }

    ${$args{output}} .= $text;

    return $chunk;
}

sub __deepen {
    my ($self, $items) = @_;

    return [] unless $items && @$items;

    my $root = {
        children => [],
    };

    foreach my $item (@$items) {
        my @path = @{$item->{path}};
        $item->{children} = [];
        my $cursor = $root->{children};
        for (my $i = 0; $i < $#path; ++$i) {
            $cursor = $cursor->[$path[$i] - 1]->{children};
        }
        $cursor->[$path[-1] - 1] = $item;
    }

    foreach my $item (@$items) {
        delete $item->{children} if !@{$item->{children}};
    }

    return $root->{children};
}

1;
