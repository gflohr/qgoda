#! /bin/false

package Qgoda::Builder;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');

sub new {
	my $self = '';
	bless \$self, shift;
}

sub build {
	my ($self, $site) = @_;
	
    my $logger = $self->logger;
    $logger->debug(__"start building posts");
    
    foreach my $asset ($site->getAssets) {
    	my $permalink = $self->expandLink($asset->{permalink});
    }   
     
    return $self;
}

sub logger {
	my ($self) = @_;
	
    require Qgoda;
    my $logger = Qgoda->new->logger('builder');    
}


1;

=head1 NAME

Qgoda::Builder - Default builder for Qgoda posts.