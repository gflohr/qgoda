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

package Template::Plugin::Qgoda;

use strict;

use base qw(Template::Plugin);

use Locale::TextDomain qw('com.cantanea.qgoda');
use File::Spec;
use Cwd;
use URI;
use Scalar::Util qw(reftype);

use Qgoda;
use Qgoda::Util qw(merge_data);
use Qgoda::Builder;

sub new {
	my ($class) = @_;
	
	return $class if ref $class;
	
	my $self = '';
	bless \$self, $class;
}

sub bust_cache {
	my ($self, $uri) = @_;

    return $uri if $uri !~ m{^/};

    my($scheme, $authority, $path, $query, $fragment) =
        $uri =~ m|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|o;
    return if !defined $path;
       
    require Qgoda;
    my $srcdir = Qgoda->new->config->{srcdir};
    my $fullpath = File::Spec->canonpath(File::Spec->catfile($srcdir, $path));
    
    my @stat = stat $fullpath or return $uri;
    if (defined $query) {
    	return "$uri&$stat[9]"
    } else {
    	return "$uri?$stat[9]"
    }
}

sub include {
	my ($self, $path) = @_;
	
	my $asset = $self->__include($path, {});
	
	return $asset->{content};
}

sub __include {
	my ($self, $_path, $overlay) = @_;

    require Qgoda;
    my $q = Qgoda->new;
    my $srcdir = $q->config->{srcdir};
    
    my $path = Cwd::abs_path($_path);
    if (!defined $path) {
    	die __x("error including '{path}': {error}.\n",
    	        path => $_path, error => $!);
    }

    my $relpath = File::Spec->abs2rel($path, $srcdir);
    my $asset = Qgoda::Asset->new($path, $relpath);
    
    my $site = $q->getSite;
    my $analyzers = $q->getAnalyzers;
    foreach my $analyzer (@{$analyzers}) {
        $analyzer->analyzeAsset($asset, $site, 1);
    }
    
    merge_data $asset, $overlay;
    
    $q->locateAsset($asset, $site);
    
    my $builders = $q->getBuilders;
    foreach my $builder (@{$builders}) {
    	$builder->processAsset($asset, $site);
    }
    
	return $asset;
}

sub list {
	my ($self, @filters) = @_;

	my $site = Qgoda->new->getSite;
	
	return $self->__extractAnd([grep {!$_->{raw}} $site->getAssets], \@filters);
}

sub listPosts {
    my ($self, @filters) = @_;
    
    return $self->list([type => 'post'], @filters);
}

sub link {
    my ($self, @filters) = @_;
    
    my $set = $self->list(@filters);
    if (@$set == 0) {
        die "broken link()\n";
    } if (@$set > 1) {
        die "ambiguous link()\n"; 
    }
    
    return $set->[0]->{permalink};
}

sub linkPost {
    my ($self, @filters) = @_;
    
    my $set = $self->list([type => 'post'], @filters);
    if (@$set == 0) {
        die "broken linkPost()\n";
    } if (@$set > 1) {
        die "ambiguous linkPost()\n"; 
    }
    
    return $set->[0]->{permalink};
}

sub writeAsset {
	my ($self, $path, $overlay) = @_;

    my $asset = $self->__include($path);
    
    my $q = Qgoda->new;
    my $logger = $q->logger('template');
    my $builder = Qgoda::Builder->new;
    my $site = $q->getSite;

    $builder->saveArtefact($asset, $site, $asset->{location});
    $logger->debug(__x("successfully built '{location}'",
                       location => $asset->{location}));
    
    return $self;
}

# If requested, this could be extended so that a ORing of filters can also
# be implemented.
sub __extractAnd {
    my ($self, $set, $filters) = @_;

    die __"list filter must be an array reference"  
        if !ref $filters || 'ARRAY' ne reftype $filters;
    
    my @set = @$set;
    my $site = Qgoda->new->getSite;
    foreach my $filter (@$filters) {
    	@set = ();
    	die __"filter items must be array references"
            if !ref $filters || 'ARRAY' ne reftype $filters;
        my ($taxonomy, $value) = @$filter;
        my $lookup = $site->getAssetsInTaxonomy($taxonomy, $value);
        foreach my $asset (@$set) {
        	push @set, $asset if exists $lookup->{$asset->getRelpath};
        }
        return [] if !@set;
        $set = [@set];
    }
    
    return \@set;
}

sub sortBy {
    my ($self, $field, $assets) = @_;

    return [sort { $a->{$field} cmp $b->{$field} } @$assets];
}

sub nsortBy {
    my ($self, $field, $assets) = @_;

    return [sort { $a->{$field} <=> $b->{$field} } @$assets];
}

1;
