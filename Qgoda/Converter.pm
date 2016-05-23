#! /bin/false

package Qgoda::Converter;

use strict;

use Locale::TextDomain qw(com.cantanea.qgoda);

sub new {
	bless {}, shift;
}

sub convert {
	my ($self, $asset, $site, $content) = @_;
	
	die __x("Converter class '{class}' does not implement the method convert().\n",
	        class => ref $self);
}

1;

=head1 NAME

Qgoda::Converter - Abstract base class for all Qgoda Converters.
