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
use Qgoda::Util qw(merge_data empty);
use Qgoda::Builder;

sub new {
	my ($class, $context) = @_;
	
	return $class if ref $class;

    my $get_values = sub {
        my ($assets, @fields) = @_;
        
        my $stash = $context->stash->clone;
        
        # Find a random variable name.
        my $name = 'a';
        while (1) {
        	last if empty $stash->get($name);
        	++$name;
        }
        
        my @values;
        my $i = 0;
        foreach my $asset (@$assets) {
        	my @subvalues;
        	push @values, [$i++, \@subvalues];
        	
        	# The variable name 'asset' is therefore not available.
        	$stash->set($name => $asset);
        	foreach my $field (@fields) {
        		push @subvalues, $stash->get("$name.$field");
        	}
        }
        
        $stash->declone;
        
        return @values;
    };
    
    sub compare_array {
        my $arr1 = $a->[1];
        my $arr2 = $b->[1];
        
        for (my $i = 0; $i < @$arr1; ++$i) {
            my ($val1, $val2) = ($arr1->[$i], $arr2->[$i]);
            
            return $val1 cmp $val2 if $val1 cmp $val2;
        }
        
        return 0;
    }
    
    sub ncompare_array {
        my $arr1 = $a->[1];
        my $arr2 = $b->[1];
        
        for (my $i = 0; $i < @$arr1; ++$i) {
            my ($val1, $val2) = ($arr1->[$i], $arr2->[$i]);
            
            return $val1 <=> $val2 if $val1 <=> $val2;
        }
        
        return 0;
    }
    
    my $sort_by = sub {
        my ($assets, $field) = @_;

        # Schwartzian transform.
        return [
            map { $assets->[$_->[0]] }
            sort compare_array $get_values->($assets, $field)
        ];
                
        return [sort { $a->{$field} cmp $b->{$field} } @$assets];
    };

    my $nsort_by = sub {
        my ($assets, $field) = @_;

        # Schwartzian transform.
        return [
            map { $assets->[$_->[0]] }
            sort ncompare_array $get_values->($assets, $field)
        ];
                
        return [sort { $a->{$field} cmp $b->{$field} } @$assets];
    };

    $context->define_vmethod(list => sortBy => $sort_by);
    $context->define_vmethod(list => nsortBy => $nsort_by);
    $context->define_vmethod(scalar => slugify => \&Qgoda::Util::slugify);
    $context->define_vmethod(scalar => escape => \&Qgoda::Util::html_escape);
    $context->define_vmethod(scalar => unmarkup => \&Qgoda::Util::unmarkup);
    
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

# TT2 distinguishes between hash and list arguments ...
sub __unwrapHash {
    my ($self, %hash) = @_;

    foreach my $key (keys %hash) {
        if (ref $key && 'HASH' eq ref $key && !defined $hash{$key}) {
            my $subhash = $key;
            foreach my $subkey (keys %hash) {
                $hash{$subkey} = $subhash->{$subkey};
            }
            last;
        }
    }

    return %hash;
}

sub include {
	my ($self, $path, $overlay, %extra) = @_;

	my $asset = $self->__include($path, $overlay, %extra);
	
	return $asset->{content};
}

sub __include {
	my ($self, $_path, $overlay, %extra) = @_;

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
    
    $q->locateAsset($asset, $site);
    
    if ($overlay) {
        my %overlay = %$overlay;
        delete $overlay{path};
        delete $overlay{view};
        delete $overlay{chain};
        delete $overlay{wrapper};
        merge_data $asset, \%overlay;
    }

    foreach my $key (keys %extra) {
        $asset->{$key} = $extra{$key};
    }
    
    my $builders = $q->getBuilders;
    foreach my $builder (@{$builders}) {
    	$builder->processAsset($asset, $site);
    }
    
	return $asset;
}

sub list {
	my ($self, @filters) = @_;

        foreach my $filter (@filters) {
            die __"List filter must be an array reference.\n"  
                if !ref $filter || 'ARRAY' ne reftype $filter;
        }

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

sub llink {
    my ($self, $lingua, @filters) = @_;

    return $self->link([lingua => $lingua], @filters);
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

sub llinkPost {
    my ($self, $lingua, @filters) = @_;

    return $self->linkPost([lingua => $lingua], @filters);
}

sub writeAsset {
	my ($self, $path, $overlay, %extra) = @_;

    my $asset = $self->__include($path, $overlay, %extra);
    
    my $q = Qgoda->new;
    my $logger = $q->logger('template');
    my $builder = Qgoda::Builder->new;
    my $site = $q->getSite;

    $builder->saveArtefact($asset, $site, $asset->{location});
    $logger->debug(__x("successfully built '{location}'",
                       location => $asset->{location}));
    
    return '';
}

# If requested, this could be extended so that a ORing of filters can also
# be implemented.
sub __extractAnd {
    my ($self, $set, $filters) = @_;

    my @set = @$set;
    my $site = Qgoda->new->getSite;
    foreach my $filter (@$filters) {
    	@set = ();
    	die __"filter items must be array references"
            if !ref $filter || 'ARRAY' ne reftype $filter;
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

1;
