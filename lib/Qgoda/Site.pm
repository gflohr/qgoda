#! /bin/false

package Qgoda::Site;

use strict;

use Qgoda::Artefact;

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

sub addArtefact {
	my ($self, $path, $origin) = @_;
	
	my $artefact = Qgoda::Artefact->new($path, $origin);
    $self->{artefacts}->{$path} = $artefact;
    
    return $self;
}

sub getArtefact {
    my ($self, $name) = @_;
    
    return if !exists $self->{artefacts}->{$name};
    
    return $self->{artefacts}->{$name};
}

sub getArtefacts {
	values %{shift->{artefacts}};
}

# Only works for top-level keys!
sub getMetaValue {
	my ($self, $key, $asset) = @_;
	
	if (exists $asset->{$key}) {
		return $asset->{$key};
	} elsif (exists $self->{config}->{$key}) {
		return $self->{config}->{$key};
	}
	
	return;
}

1;
