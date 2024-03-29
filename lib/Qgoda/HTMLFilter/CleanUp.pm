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

package Qgoda::HTMLFilter::CleanUp;

use strict;

#VERSION

use Qgoda;

sub new {
	my ($class, %args) = @_;

	bless {}, $class;
}

sub comment {
	my ($self, $chunk, %args) = @_;

	if ($chunk =~ /^<!--\[if/i) {
	   return $chunk;
	}

	return '';
}

sub start {
	my ($self, $chunk, %args) = @_;

	if ('a' eq lc $args{tagname}
	    && defined $args{attr}->{href}
	    && $args{attr}->{href} =~ s/([!,.:;?])$//) {
		$self->{__interpunction} = $1;
		$chunk = '<' . $args{tagname};

		my $attrseq = $args{attrseq};
		my $attr = $args{attr};
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
	}

	return $chunk;
}

sub text {
	my ($self, $chunk, %args) = @_;

	my $interpunction = $self->{__interpunction};
	if (length $interpunction) {
		$chunk =~ s/[$interpunction]$//;
	}

	return $chunk;
}

sub end {
	my ($self, $chunk, %args) = @_;

	my $interpunction = delete $self->{__interpunction} // '';
	if ('a' eq $args{tagname}) {
		return $chunk . $interpunction;
	} else {
		return $interpunction . $chunk;
	}
}

1;
