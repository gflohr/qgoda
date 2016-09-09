#! /bin/false

# Copyright (C) 2016 Guido Flohr <guido.flohr@cantanea.com>, 
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

package Qgoda::Site;

use strict;

use Qgoda::Artefact;

sub new {
    my ($class, $config) = @_;

    my $self = {
    	config => $config,
        assets => {},
        artefacts => {},
        taxonomies => {},
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
    sort { $a->{priority} <=> $b->{priority} }values %{shift->{assets}};
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
	}
	
	my $config = $self->{config};
	if (exists $config->{$key}) {
		return $config->{$key};
	}
	
	return;
}

sub getTrigger {
	my ($self, @suffixes) = @_;
	
	my $triggers = $self->{config}->{processors}->{triggers};
	for (my $i = $#suffixes; $i >= 0; --$i) {
		return $suffixes[$i] 
		    if exists $triggers->{$suffixes[$i]};
	}
	
	return;
}

sub getChainByTrigger {
	my ($self, $trigger) = @_;
	
	my $config = $self->{config}->{processors};
	my $name = $config->{triggers}->{$trigger};
	return if !defined $name;
	my $chain = $config->{chains}->{$name} || return;
    
    return wantarray ? ($chain, $name) : $chain;
}

sub getChain {
	my ($self, $asset) = @_;
	
	my $suffixes = $asset->{suffixes} or return;
	my $trigger = $self->getTrigger(@$suffixes);
	return unless defined $trigger;
	my $chain = $self->getChainByTrigger($trigger) or return;
	
	return $chain;
}

sub addTaxonomy {
    my ($self, $taxonomy, $asset, $value) = @_;

    $self->{__taxonomies}->{$taxonomy} ||= {};
    $self->{__taxonomies}->{$taxonomy}->{$value} ||= {};
    
    $self->{__taxonomies}->{$taxonomy}->{$value}->{$asset->getRelpath} = $asset;
    
    return $self;    
}

sub getAssetsInTaxonomy {
    my ($self, $taxonomy, $value) = @_;
    
    return {} if !exists $self->{__taxonomies};
    return {} if !exists $self->{__taxonomies}->{$taxonomy};
    
    return $self->{__taxonomies}->{$taxonomy}->{$value} || {}
}

1;
