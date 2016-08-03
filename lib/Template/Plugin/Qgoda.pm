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
	my ($self, $_path) = @_;

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
    
    my $builders = $q->getBuilders;
    foreach my $builder (@{$builders}) {
    	$builder->processAsset($asset, $site);
    }
    
	return $asset->{content};
}

1;
