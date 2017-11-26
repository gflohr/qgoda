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

package Qgoda::Processor;

use strict;

use Locale::TextDomain qw(com.cantanea.qgoda);
use Scalar::Util qw(blessed);
use URI;
use URI::Escape qw(uri_unescape);

use Qgoda::Util qw(empty);

sub new {
    bless {}, shift;
}

sub process {
    my ($self, $content, $asset) = @_;

    die __x("Processor class '{class}' does not implement the method process().\n",
            class => ref $self);
}

sub postMeta {
    my ($self, $content, $asset) = @_;

    require HTML::TreeBuilder;
    my $tree = HTML::TreeBuilder->new(implicit_body_p_tag => 1,
                                  ignore_ignorable_whitespace => 1);
    $tree->parse($content);

    my @paragraphs = $tree->find('p', 'div');
    my $excerpt = '';
    foreach my $paragraph (@paragraphs) {
        my @children = $paragraph->content_list;
        foreach my $child (@children) {
            # On recent Perls "next if $child->isa()" would be sufficient.
            # On older Perls it is not.
            next if ref $child && blessed $child && $child->isa('HTML::Element');
            $excerpt = $child;
            $excerpt =~ s/^[ \t\r\n]+//;
            $excerpt =~ s/[ \t\r\n]+$//;
            last;
        }

        last;
    }

    # Collect links.
    my %links;
    foreach my $record (@{$tree->extract_links}) {
        my $link = eval {
            URI->new(uri_unescape $record->[0])->canonical;
        };
        ++$links{$link} if !empty $link;
    }

    return excerpt => $excerpt, links => \%links;
}

1;

=head1 NAME

Qgoda::Processor - Abstract base class for all Qgoda Processors.
