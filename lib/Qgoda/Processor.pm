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

use Locale::TextDomain qw(qgoda);
use Scalar::Util qw(blessed);
use URI;
use URI::Escape qw(uri_unescape);

use Qgoda;
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

    my $case_sensitive = Qgoda->new->config->{'case-senstive'};

    require HTML::TreeBuilder;
    my $tree = HTML::TreeBuilder->new(implicit_body_p_tag => 1,
                                  ignore_ignorable_whitespace => 1);
    $tree->parse($content);

    my @paragraphs = $tree->find('p', 'div');
    my $excerpt = '';
    foreach my $paragraph (@paragraphs) {
        $excerpt = $paragraph->as_text;
        $excerpt =~ s/^[ \t\r\n]+//;
        $excerpt =~ s/[ \t\r\n]+$//;
        last if !empty $excerpt;
    }

    # Collect links.
    my %links;
    foreach my $record (@{$tree->extract_links}) {
        my $href = uri_unescape $record->[0];
        eval {
            my $canonical = URI->new($href)->canonical;
            $href = $canonical;
        };
        if (!empty $href) {
            if ('/' eq substr $href, 0, 1) {
                $href = lc $href if !$case_sensitive;
            }
            
            # This will also count links to itself but they will be filtered
            # out by Qgoda::Site->computeRelated().
            ++$links{$href};
        }
    }

    return excerpt => $excerpt, links => [keys %links];
}

1;

=head1 NAME

Qgoda::Processor - Abstract base class for all Qgoda Processors.
