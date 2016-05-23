#! /bin/false

package Qgoda::Site;

use strict;

sub new {
    my ($class, $config) = @_;

    my $self = {
    	config => $config,
        assets => {},
        artefacts => {}
    };
    
    bless $self, $class;
}

sub addAsset {
	my ($self, $asset) = @_;
	
	my $path = $asset->getPath;
	$self->{assets}->{$path} = $asset;
	
	return $self;
}

sub getAssets {
    values %{shift->{assets}};
}

sub getArtefact {
	my ($self, $name) = @_;
	
	return if !exists $self->{artefacts}->{$name};
	
	return $self->{artefacts}->{$name};
}

1;
