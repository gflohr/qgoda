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

# FIXME! This is only needed for debugging the filter cache.  Remove it,
# once the filter cache is stable.
use MIME::Base64 qw(encode_base64);
use List::Util qw(pairs any);
use Scalar::Util qw(reftype);

use Qgoda::Util qw(canonical);
use Qgoda::Artefact;

sub new {
    my ($class, $config) = @_;

    my $self = {
        config => $config,
        assets => {},
        artefacts => {},
        __filter_cache => {},
        __modified => {},
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

sub addModified {
    my ($self, $path, $asset) = @_;

    $self->{__modified}->{$path} = $asset;

    return $self;
}

sub getModified {
    shift->{__modified};
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

sub searchAssets {
    my ($self, %filters) = @_;

    # Sort the filters, so that we can canonicalize them.
    my @_filters;
    foreach my $key (sort keys %filters) {
        push @_filters, $key, $filters{$key};
    }

    my $canonical = encode_base64 canonical \@_filters;
    if (exists $self->{__filter_cache}->{$canonical}) {
        my @copy;
        foreach my $path (@{$self->{__filter_cache}->{$canonical}}) {
            push @copy, $self->{assets}->{$path}
                if $self->{assets}->{$path};
        }
        return \@copy;
    }

    # Preprocess the filters.
    my $visualize = sub {
        my ($index) = @_;

        $_filters[$index] = ">>>$_filters[$index]<<<";
        join ', ', @_filters;
    };

    my @filters;
    my %operators = (
        eq    => sub { $_[0] eq $_[1] },
        ne    => sub { $_[0] ne $_[1] },
        ge    => sub { warn "'$_[0]' ge '$_[1]'?\n"; $_[0] ge $_[1] },
        gt    => sub { $_[0] gt $_[1] },
        le    => sub { $_[0] le $_[1] },
        lt    => sub { $_[0] lt $_[1] },
        ieq   => sub { (lc $_[0]) eq (lc $_[1]) },
        ine   => sub { (lc $_[0]) ne (lc $_[1]) },
        ige   => sub { (lc $_[0]) ge (lc $_[1]) },
        igt   => sub { (lc $_[0]) gt (lc $_[1]) },
        ile   => sub { (lc $_[0]) le (lc $_[1]) },
        ilt   => sub { (lc $_[0]) lt (lc $_[1]) },
        '=='  => sub { $_[0] == $_[1] },
        '!='  => sub { $_[0] != $_[1] },
        '>='  => sub { $_[0] >= $_[1] },
        '>'   => sub { $_[0] >  $_[1] },
        '<='  => sub { $_[0] <= $_[1] },
        '<'   => sub { $_[0] <  $_[1] },
        '=~'  => sub { $_[0] =~ $_[1] },
        '!~'  => sub { $_[0] !~ $_[1] },
        '&'   => sub { $_[0] &  $_[1] },
        '|'   => sub { $_[0] |  $_[1] },
        '^'   => sub { $_[0] ^  $_[1] },
        'contains' => sub {
            my @haystack;
            if (ref $_[0] && 'ARRAY' eq reftype $_[0]) {
                @haystack = @{$_[0]};
            } elsif (ref $_[0] && 'HASH' eq reftype $_[0]) {
                @haystack = keys %{$_[0]};
            } else {
                @haystack = ($_[0]);
            }
            any { $_[1] eq $_ } @haystack;
        },
        'icontains' => sub {
            my @haystack;
            if (ref $_[0] && 'ARRAY' eq reftype $_[0]) {
                @haystack = @{$_[0]};
            } elsif (ref $_[0] && 'HASH' eq reftype $_[0]) {
                @haystack = keys %{$_[0]};
            } else {
                @haystack = ($_[0]);
            }
            my $needle = lc $_[1];
            any { $needle eq lc $_ } @haystack;
        },
    );

    # FIXME! Simplyfy this! We always expect a key, the value is either a
    # scalar or an array ref, containg the operator and the value.
    foreach my $kv (pairs @_filters) {
        my ($key, $value, $op) = @$kv;

        if (ref $value && 'ARRAY' eq reftype $value) {
            ($op, $value) = @$value;
        } else {
            $op = 'eq';
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

    my @paths;
    foreach my $found (@found) {
        push @paths, $found->{path};
    }
    $self->{__filter_cache}->{$canonical} = \@paths;

    return \@found;
}

sub computeRelations {
    my ($self) = @_;

    # First pass. Get permalinks.
    my %locations;
    my %permalinks;
    my $taxonomies = Qgoda->new->config->{taxonomies};
    my %taxonomies;
    my %links;

    foreach my $asset (values %{$self->{assets}}) {
        my $permalink = $asset->{permalink};
        $locations{$asset->{location}} = $asset;
        $permalinks{$permalink} = $asset;

        foreach my $link (keys %{$asset->{links}}) {
            $links{$link}->{$permalink} = $asset;
        }

        foreach my $key (keys %$taxonomies) {
            next if !exists $asset->{$key};
            my @values = $asset->{$key};
            @values = @{$values[0]}
                if ref $values[0] && 'ARRAY' eq reftype $values[0];
            foreach my $value (@values) {
                $taxonomies{$key}->{$value}->{$permalink} = $asset;
            }
        }
    }

    my %related;

    # Second pass.  Add values for links between assets.
    my $link_score = 5;  # FIXME! Should be configurable!
    foreach my $permalink (keys %permalinks) {
        my $asset = $permalinks{$permalink};
        my $links = $asset->{links};
        foreach my $link (keys %$links) {
            my $target;
            if (exists $permalinks{$link}) {
                $target = $permalinks{$link}
            } elsif (exists $locations{$link}) {
                $target = $locations{$link};
            }

            if ($target && $target != $asset) {
                $related{$permalink}->{$target->{permalink}} += $link_score;
                $related{$target->{permalink}}->{$permalink} += $link_score;
            }
        }
    }

    my $common_link_score = 1; # FIXME! Should be configurable.
    foreach my $link (keys %links) {
        my @group = keys %{$links{$link}};
        foreach my $from (@group) {
            foreach my $to (@group) {
                $related{$from}->{$to} += $common_link_score;
            }
        }
    }

    foreach my $permalink (keys %related) {
        my $peers = $related{$permalink};

        # Delete relation with itself.
        delete $peers->{$permalink};

        # Sort by relevance and replace score with asset-score pair.
        my @related = 
            map { [$permalinks{$_}, $peers->{$_}] }
            sort { $peers->{$a} <=> $peers->{$b} } keys %{$peers};
        
        $permalinks{$permalink}->{related} = \@related;
    }

    return $self
}

sub getTaxonomyValues {
    my ($self, $taxonomy, %filters) = @_;

    my $assets = $self->searchAssets(%filters);
    my %values;
    foreach my $asset (@$assets) {
        next if !exists $asset->{$taxonomy};

        my $value = $asset->{$taxonomy};
        if (ref $value && 'ARRAY' eq reftype $value) {
            map { $values{$_} = 1 } @$value;
        } elsif (ref $value && 'HASH' eq reftype $value) {
            map { $values{$_} = 1 } keys %$value;
        } else {
            $values{$value} = 1;
        }
    }

    return keys %values;
}

1;
