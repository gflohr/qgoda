#! /bin/false

package Qgoda::Builder;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');

use Qgoda::Util qw(empty expand_perl_format);

sub new {
	my $self = '';
	bless \$self, shift;
}

sub build {
	my ($self, $site) = @_;
	
    my $logger = $self->logger;
    $logger->debug(__"start building posts");
    
    foreach my $asset ($site->getAssets) {
    	$logger->debug(__x("building post '{relpath}'",
    	                   relpath => $asset->getRelpath));
    	                   
    	my $permalink = $self->expandLink($asset, $asset->{permalink});
        $logger->debug(__x("permalink '{permalink}'",
                           permalink => $permalink));
    }   
     
    return $self;
}

sub logger {
	my ($self) = @_;
	
    require Qgoda;
    my $logger = Qgoda->new->logger('builder');    
}

sub expandLink {
	my ($self, $asset, $link) = @_;
	
	return '/' . $asset->getRelpath if empty $link;

	return expand_perl_format $link, $asset;
}

1;

=head1 NAME

Qgoda::Builder - Default builder for Qgoda posts.