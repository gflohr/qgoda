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

package Qgoda::Analyzer;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');
use Date::Parse;
use YAML;
use File::Basename qw(fileparse);
use Scalar::Util qw(reftype);

use Qgoda::Util qw(empty yaml_error front_matter lowercase
                   normalize_path strip_suffix merge_data slugify);

sub new {
    my ($class) = @_;

    require Qgoda;
    my $logger = Qgoda->new->logger('analyzer');
    my $config = Qgoda->new->config;

    bless {
    	__logger => $logger,
    	__config => $config,
    }, $class;
}

sub analyze {
	my ($self, $site, $included) = @_;
	
	foreach my $asset ($site->getAssets) {
		$self->analyzeAsset($asset, $site, $included);
	}
	
	return $self;
}

sub analyzeAsset {
	my ($self, $asset, $site, $included) = @_;
	
    my $logger = $self->{__logger};

    my $path = $asset->getPath;
    $logger->debug(__x("analyzing asset '{path}'", 
                       path => $path));
    stat $path or die __x("error reading '{path}': {err}",
                          path => $path, err => $!);
    my $front_matter = front_matter $path;

    my $meta = {};
    if (!empty $front_matter) {
        $meta = eval { YAML::Load($front_matter) };
        if ($@) {
            $logger->error(yaml_error $path, $@);
            next;
        }
    } else {
        $meta->{raw} = 1;
    }
    
    foreach my $key (keys %$meta) {
        next if 'path' eq $key;
        next if 'relpath' eq $key;
        $asset->{$key} = $meta->{$key};
    }
    
    $self->__fillMeta($asset, $site) if !$asset->{raw};
    $self->__fillTaxonomies($asset, $site) if !$included && !$asset->{raw};
     
	return $self;
}

sub __fillMeta {
	my ($self, $asset, $site) = @_;
	
	my $logger = $self->{__logger};
	my $config = $self->{__config};
	
    my $date = $asset->{date};
    if (defined $date) {
    	if ($date !~ /^-?[1-9][0-9]*$/) {
    		$date = str2time $date;
    		if (!defined $date) {
    			$logger->error(__x("{filename}: cannot parse date '{date}'",
    			                   date => $asset->{date}));
    		}
    	}
    }
 
    if (!defined $date) {
    	my @stat = stat $asset->getPath;
        if (!@stat) {
            $logger->error(__x("cannot stat '{filename}': {error}",
                               filename => $asset->getPath, error => $!));
            $date = time;
        } else {
        	$date = $stat[9];
        }
    }
 
    my ($seconds, $minutes, $hour, $mday, $month, $year, $wday, $yday, $isdst)
        = localtime $date;
    $asset->{date} = {
    	epoch => $date,
        sec => (sprintf '%02u', $seconds),
        isec => (sprintf '%u', $seconds),
        min => (sprintf '%02u', $minutes),
        imin => (sprintf '%u', $minutes),
        hour => (sprintf '%02u', $hour),
        ihour => (sprintf '%u', $hour),
        hour12 => (sprintf '%02u', $hour % 12 || 12),
        ihour12 => (sprintf '%u', $hour % 12 || 12),
        ampm => ($hour < 12 ? 'a. m.' : 'p. m.'),
        mday => (sprintf '%02u', $mday),
        imday => (sprintf '%u', $mday),
        day => (sprintf '%02u', $mday),
        iday => (sprintf '%u', $mday),
        month => (sprintf '%02u', $month + 1),
        imonth => (sprintf '%u', $month + 1),
        year => (sprintf '%02u', $year + 1900),
        wday => $wday,
        yday => $yday,
        isdst => $isdst,
    };

    $self->__fillPathInformation($asset, $site);

    $asset->{title} = $asset->{basename} if !exists $asset->{title};
    $asset->{slug} = $self->__slug($asset);

    $asset->{view} = $site->getMetaValue(view => $asset);
    $asset->{type} = $site->getMetaValue(type => $asset);

    return $self;
}

sub __fillTaxonomies {
    my ($self, $asset, $site) = @_;
    
    my $logger = $self->{__logger};
    my $config = $self->{__config};
    
    my $taxonomies = $config->{taxonomies};
    foreach my $t (keys %$taxonomies) {
    	next if !exists $asset->{$t};
    	my @values;
    	if (ref $asset->{$t} && 'ARRAY' eq reftype $asset->{$t}) {
    		@values = @{$asset->{$t}};
    	} else {
    		@values = $asset->{$t};
    	}
    	
    	foreach my $value (@values) {
    		$site->addTaxonomy($t, $asset, $value);
    	}
    }
    
    return $self;
}

sub __slug {
	my ($self, $asset) = @_;
	
	return slugify $asset->{title};
}

sub __fillPathInformation {
	my ($self, $asset, $site) = @_;
	
	my $relpath = $asset->getRelpath;
	my ($filename, $directory) = fileparse $relpath;
	
	$asset->{filename} = $filename;
	
    $directory = normalize_path $directory;
    $directory = '' if '.' eq $directory;
    $asset->{directory} = $directory;
    
    my ($basename, @suffixes) = strip_suffix $filename;
    $asset->{basename} = $basename;
    
    if (empty $asset->{chain}) {
	    my $trigger = $site->getTrigger(@suffixes);
	    if (!empty $trigger) {
	        my ($chain, $name) = $site->getChainByTrigger($trigger);
	        $asset->{chain} = $name if $chain;
	        if ($chain && exists $chain->{suffix}) {
	            for (my $i = $#suffixes; $i >= 0; --$i) {
	                if ($suffixes[$i] eq $trigger) {
	                    $suffixes[$i] = $chain->{suffix};
	                    last;
	                }
	            }
	        }
	    }
    }
    
    $asset->{suffixes} = \@suffixes;
    if (@suffixes) {
        $asset->{suffix} = '.' . join '.', @suffixes;
    }

    $asset->{location} = $site->getMetaValue(location => $asset);
    $asset->{permalink} = $site->getMetaValue(permalink => $asset);
    $asset->{index} = $site->getMetaValue(index => $asset);
    
	return $self;
}

1;
