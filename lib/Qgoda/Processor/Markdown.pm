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

package Qgoda::Processor::Markdown;

use strict;

#VERSION

use base qw(Qgoda::Processor);

use Text::Markdown::Discount qw(markdown);

BEGIN {
	Text::Markdown::Discount::with_html5_tags();
}

sub new {
	my ($class, %options) = @_;

	my $self = $class->SUPER::new(%options);
	$self->{__options} = \%options;

	return $self;
}

sub process {
	my ($self, $content, $asset, $filename) = @_;

	# Do not add 0x00001000 (MKD_TOC) here.
	my $flags =
		  0x00000004 # do not do Smartypants-style mangling of quotes, dashes, or ellipses.
		| 0x00004000 # make http://foo.com link even without <>s
		| 0x00200000 # enable markdown extra-style footnotes
		| 0x01000000 # enable extra-style definition lists
		| 0x02000000 # enabled fenced code blocks
		| 0x08000000 # enable dash and underscore in element names
		| 0x40000000 # handle embedded LaTex escapes
		| 0x80000000 # don't combine numbered bulletted lists
		;
	return markdown $content, $flags;
}

1;

=head1 NAME

Qgoda::Processor::Markdown - Qgoda Processor For Markdown
