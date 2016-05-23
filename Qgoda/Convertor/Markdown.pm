#! /bin/false

package Qgoda::Convertor::Markdown;

use strict;

use base qw(Qgoda::Convertor);

use Text::Markdown qw(markdown);

sub new {
	my ($class, %options) = @_;
	
	my $self = $class->SUPER::new(%options);
	$self->{__options} = \%options;
	
	return $self;
}

sub convert {
	my ($self, $asset, $site, $content) = @_;
	
	return markdown $content, $self->{__options};
}

1;

=head1 NAME

Qgoda::Convertor::Markdown - Default builder for Qgoda posts.
