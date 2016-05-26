#! /bin/false

package Qgoda::Analyzer;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');
use Date::Parse;
use YAML;
use File::Basename qw(fileparse);

use Qgoda::Util qw(read_file empty yaml_error front_matter lowercase
                   normalize_directory strip_suffix);

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
	my ($self, $site) = @_;
	
	my $logger = $self->{__logger};
	foreach my $asset ($site->getAssets) {
		my $path = $asset->getPath;
		$logger->debug(__x("analyzing asset '{path}'", 
		                   path => $asset->getPath));
		my $front_matter = front_matter $path;
		
		# FIXME! Fill $meta with defaults!
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
		
		# FIXME! Merge the front matter into the meta information preserving
		# the immutable properties.
		foreach my $key (keys %$meta) {
			next if 'path' eq $key;
			next if 'relpath' eq $key;
			$asset->{$key} = $meta->{$key};
		}
		$self->__fillMeta($asset, $site);
	}
	
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
 
    $self->__fillPathInformation($asset, $site);
        
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

    $asset->{title} = $asset->{basename} if !exists $asset->{title};
    $asset->{slug} = $self->__slug($asset);

    $asset->{index} = '/index';
    my $converted_suffix = $config->getConvertedSuffix($asset);
    $asset->{index} .= '.' . $converted_suffix if !empty $converted_suffix;

    return $self;
}

sub __slug {
	my ($self, $asset) = @_;
	
	my $title = $asset->{title};
	
	use utf8;
	my $slug = lowercase $title;
	# We only allow alphanumerical characters, the dot, the hyphen and the underscore.
	# Everything else gets converted into hyphens, and sequences of hyphens
	# are condensed into one.
	$slug =~ s/[\x00-\x2c\x2f\x3a-\x5e\x60\x7b-\x7f]/-/g;
	$slug =~ s/--+/-/g;
	
	return $slug;
}

sub __fillPathInformation {
	my ($self, $asset, $site) = @_;
	
	my $relpath = $asset->getRelpath;
	my ($filename, $directory) = fileparse $relpath;
	
	$asset->{filename} = $filename;
	
    $directory = normalize_directory $directory;
    $asset->{directory} = $directory;
    
    my ($basename, @suffixes) = strip_suffixes $filename;
    $asset->{basename} = $basename;
    $asset->{suffixes} = \@suffixes;
    $asset->{suffix} = join '.', @suffixes;

    $asset->{location} = $site->getMetaValue(location => $asset);
    $asset->{permalink} = $site->getMetaValue(permalink => $asset);
    $asset->{index} = $site->getMetaValue(index => $asset);
    
	return $self;
}

1;
