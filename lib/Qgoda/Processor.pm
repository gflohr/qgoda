#! /bin/false

# Copyright (C) 2016-2023 Guido Flohr <guido.flohr@cantanea.com>,
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

#VERSION

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

	# Get the excerpt as plain text and html, and try to get the content body
	# (content minus excerpt).
	my @paragraphs = $tree->find('p', 'div');
	my $excerpt = '';
	my $excerpt_html = '';
	my $content_body = $content;
	foreach my $paragraph (@paragraphs) {
		$excerpt = $paragraph->as_text;
		$excerpt_html = $paragraph->as_HTML;
		$excerpt =~ s/^[ \t\r\n]+//;
		$excerpt =~ s/[ \t\r\n]+$//;
		if (!empty $excerpt) {
			$paragraph->delete;
			$content_body = $tree->as_HTML;
			
			# We have to remove the html wrapper that was created.
			$content_body =~ s{.*<body>}{}s;
			$content_body =~ s{</body>.*?$}{}s;
			last;
		}
	}

	return
		excerpt => $excerpt,
		excerpt_html => $excerpt_html,
		content_body => $content_body,
		links => [keys %links];
}

1;

=head1 NAME

Qgoda::Processor - Abstract base class for all Qgoda Processors.
