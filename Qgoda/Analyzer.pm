#! /bin/false

package Qgoda::Analyzer;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');
use Date::Parse;
use YAML;
use File::Basename;

use Qgoda::Util qw(read_file empty yaml_error front_matter lowercase);

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
		my $meta = {};
		if (!empty $front_matter) {
			$meta = eval { YAML::Load($front_matter) };
			if ($@) {
				$logger->error(yaml_error $path, $@);
				next;
			}
			
            if (!defined $meta->{permalink}) {
                $meta->{permalink} = '/{slug}{index}';
            }
		}
		
		foreach my $key (keys %$meta) {
			next if 'path' eq $key;
			next if 'relpath' eq $key;
			$asset->{$key} = $meta->{$key};
		}
		$self->__fillMeta($asset);
	}
	
	return $self;
}

sub __fillMeta {
	my ($self, $asset) = @_;
	
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
    	seconds => (sprintf '%02u', $seconds),
        minutes => (sprintf '%02u', $minutes),
        hour => (sprintf '%02u', $hour),
        mday => (sprintf '%02u', $mday),
        month => (sprintf '%02u', $month + 1),
        year => (sprintf '%02u', $year + 1900),
        wday => $wday,
        yday => $yday,
        isdst => $isdst,
    };

    my $stem = fileparse $asset->getPath;
    my $suffix = '';
    if ($stem =~ s/\.([^.]+)$//) {
        $suffix = $1;
    }
    $asset->{stem} = $stem;
    $asset->{title} = $asset->{stem} if !exists $asset->{title};
    $asset->{suffix} = $suffix;
    $asset->{slug} = $self->__slug($asset);

    $asset->{index} = '/index';
    $asset->{suffix} = $config->getProcessorSuffix($asset);
    $asset->{index} .= '.' . $asset->{suffix} if !empty $asset->{suffix};

    return $self;
}

sub __slug {
	my ($self, $asset) = @_;
	
	my $title = $asset->{title};
	$title = $asset->{stem} if empty $title;
	
	use utf8;
	my $slug = lowercase $title;
	# We only allow alphanumerical characters, the dot, the hyphen and the underscore.
	# Everything else gets converted into hyphens, and sequences of hyphens
	# are condensed into one.
	$slug =~ s/[\x00-\x2c\x2f\x3a-\x5e\x60\x7b-\x7f]/-/g;
	$slug =~ s/--+/-/g;
	
	return $slug;
}

1;
