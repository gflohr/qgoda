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

use Qgoda::Util qw(canonical);
use Qgoda::Artefact;

sub new {
    my ($class, $config) = @_;

    my $self = {
    	config => $config,
        assets => {},
        artefacts => {},
        taxonomies => {},
        __filter_cache => {},
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
    sort { $a->{priority} <=> $b->{priority} } values %{shift->{assets}};
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

# FIXME! Prefilter the list for simple taxonomy filters.
sub searchAssets {
    my ($self, @_filters) = @_;

    my $canonical = canonical \@_filters;
    return $self->{__filter_cache}->{$canonical}
        if exists $self->{__filter_cache}->{$canonical};

    # Preprocess the filters.
    my $visualize = sub {
        my ($index) = @_;

        $_filters[$index] = ">>>$_filters[$index]<<<";
        join ', ', @_filters;
    };

    my @filters;
    my %operators = (
        eq   => sub { $_[0] eq $_[1] },
        ne   => sub { $_[0] ne $_[1] },
        ge   => sub { $_[0] ge $_[1] },
        gt   => sub { $_[0] gt $_[1] },
        le   => sub { $_[0] le $_[1] },
        lt   => sub { $_[0] lt $_[1] },
        '==' => sub { $_[0] == $_[1] },
        '!=' => sub { $_[0] != $_[1] },
        '>=' => sub { $_[0] >= $_[1] },
        '>'  => sub { $_[0] >  $_[1] },
        '<=' => sub { $_[0] <= $_[1] },
        '<'  => sub { $_[0] <  $_[1] },
        '=~' => sub { $_[0] =~ $_[1] },
        '!~' => sub { $_[0] !~ $_[1] },
        '&'  => sub { $_[0] &  $_[1] },
        '|'  => sub { $_[0] |  $_[1] },
        '^'  => sub { $_[0] ^  $_[1] },
    );

    for (my $i = 0; $i < @_filters; ++$i) {
        my ($key, $value, $op);

        $key = $_filters[$i];

        if (ref $key) {
            if ('HASH' eq reftype $key) {
                my @keys = keys %$key;
                if (@keys != 1) {
                    die __x("invalid filter (only one hash key allowed): {filter}\n",
                            filter => $visualize->($i));
                }
                $value = $key->{$keys[0]};
                $key = $keys[0];
                $op = 'eq';
            } elsif ('ARRAY' eq reftype $key) {
                if (@$key > 2) {
                    ($key, $op, $value) = @$key;
                } else {
                    ($key, $value) = @$key;
                }
                $value = '' if !defined $value;
                $op = 'eq' if !defined $op;
            } else {
                # Stringify.
                $key = "$key";
                --$i;
            }
        } else {
            if ($i == $#_filters) {
                die __x("invalid filter (missing last value): {filter}\n",
                         filter => $visualize->($i));                
            }
            $op = 'eq';
            $value = $_filters[++$i];
        }

        push @filters, [$op, $key, $value];
    }

    foreach my $filter (@filters) {
        my ($op, $key, $value) = @$filter;
        my $sub = $operators{$op} || $operators{eq};

        if ('=~' eq $op || '!~' eq $op) {
            $value = eval { qr/$value/ };
            die __x("invalid regular expression in filter: {error}",
                    error => $@);
        }
        $filter->[0] = $sub;
        $filter->[2] = $value;
    }

	my @found = values %{$self->{assets}};

	{
        no warnings;

		foreach my $filter (@filters) {
			@found = grep {
                my $asset = $_;
                my ($sub, $key, $value) = @$filter;

				$sub->($asset->{$key}, $value);
			} @found;
		}
	}

    return $self->{__filter_cache}->{$canonical} = \@found;
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

sub getTaxonomyValues {
	my ($self, $taxonomy) = @_;
	
	return [] if !exists $self->{__taxonomies};
    return [] if !exists $self->{__taxonomies}->{$taxonomy};

    return [keys %{$self->{__taxonomies}->{$taxonomy}}];
}

1;
