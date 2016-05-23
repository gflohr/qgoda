#! /bin/false

package Qgoda::Convertor;

use strict;

use Locale::TextDomain qw(com.cantanea.qgoda);

sub new {
	my $self = '';
	bless \$self, shift;
}

sub convert {
	my ($self, $asset, $site, $content) = @_;
	
	die __x("Convertor class '{class}' does not implement the method convert().\n",
	        class => ref $self);
}

1;

=head1 NAME

Qgoda::Convertor - Abstract base class for all Qgoda Convertors.