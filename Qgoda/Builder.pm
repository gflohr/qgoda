#! /bin/false

package Qgoda::Builder;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');
use File::Spec;

use Qgoda::Util qw(empty expand_perl_format read_file read_body write_file);

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
    	                   
    	my $permalink = $self->expandLink($asset, $site, $asset->{permalink});
        $logger->debug(__x("permalink '{permalink}'",
                           permalink => $permalink));

        my $content = $self->readAssetContent($asset, $site);

        $self->saveArtefact($asset, $site, $permalink, $content);
    }   
     
    return $self;
}

sub logger {
	my ($self) = @_;
	
    require Qgoda;
    my $logger = Qgoda->new->logger('builder');    
}

sub expandLink {
	my ($self, $asset, $site, $link) = @_;
	
	return '/' . $asset->getRelpath if empty $link;

	return expand_perl_format $link, $asset;
}

sub readAssetContent {
	my ($self, $asset, $site) = @_;
	
	if ($asset->{raw}) {
		return read_file($asset->getPath);
	} else {
		return read_body($asset->getPath);
	}
}

sub saveArtefact {
	my ($self, $asset, $site, $permalink, $content) = @_;
	
    require Qgoda;
    my $config = Qgoda->new->config;
    $permalink = '/' . $asset->getRelpath if empty $permalink;
    my $path = File::Spec->catdir($config->{outdir}, $permalink);
    
    my $existing = $site->getArtefact($path);
    if ($existing) {
    	my $origin = $existing->getAsset;
    	my $logger = $self->logger;
        $logger->warning(__x("Overwriting artefact at '{outpath}', "
                             . "origin: {origin}",
                             outpath => $path,
                             origin => $origin ? $origin->getOrigin : __"[unknown origin]"));
    }
    
    unless (write_file $path, $content) {
    	my $logger = $self->logger;
    	$logger->error(__x("error writing '{filename}': {error}",
    	                   filename => $path, error => $!));
    	return;
    }
    
    $site->addArtefact($path, $asset);
}

1;

=head1 NAME

Qgoda::Builder - Default builder for Qgoda posts.