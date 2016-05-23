#! /bin/false

package Qgoda::Config;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');
use File::Spec;
use YAML;
use Cwd;
use Scalar::Util qw(reftype);

use Qgoda::Util qw(read_file empty yaml_error);
use Qgoda::Convertor::Null;

sub new {
    my ($class, %args) = @_;

    require Qgoda;
    my $logger = Qgoda->new->logger('config');
    
    my $filename;
    if (!empty $args{filename}) {
        $filename = $args{filename};
    } elsif (-e '_config.yaml') {
        $filename = '_config.yaml';
    } elsif (-e '_config.yml') {
        $filename = '_config.yml';
    } else {
        $logger->warning(__"config file 'config.yaml' not found, "
                           . "proceeding with defaults.");
    }

    my $config = {};
    if (!empty $filename) {
        $logger->info(__x("reading configuration from '{filename}'",
                          filename => '_config.yaml'));
        my $yaml = read_file $filename;
        if (!defined $yaml) {
        	$logger->fatal(__x("error reading file '{filename}': {error}",
        	                   filename => $filename, error => $!));
        }
        $config = eval { YAML::Load($yaml) };
        $logger->fatal(yaml_error $filename, $@) if $@;
    }
    my $self = bless $config, $class;

    unless ($self->__isHash($config)) {
    	$logger->fatal(__x("invalid configuration file '{filename}' (not a hash)",
    	                   filename => $filename));
    }
    
    # Fill in defaults and consistency checks.
    $config->{title} = __"A site powered by Qgoda"
        if empty $config->{title};
    $config->{srcdir} = '.'
        if empty $config->{srcdir};
    $config->{outdir} = File::Spec->catpath($config->{srcdir}, '_site')
        if empty $config->{outdir};
    $config->{processors} ||= {
    	'm(?:arkdown|down|kdn|dwn|kd|d)' => {
    		convertor => 'Markdown', 
    		suffix => 'html'
    	},
    	'html?' => {
    		convertor => 'Null',
    		suffix => 'html'
    	},
    };

    unless ($self->__isHash($config->{processors})) {
        $logger->fatal(__x("{filename}: processors must be a hash",
                           filename => $filename));
        foreach my $suffix (keys %{$config->{processors}}) {
        	my $record = $config->{processors}->{$suffix};
        	unless ($self->__isHash($record)
        	        && !empty $record->{convertor}
        	        && !empty $record->{suffix}) {
                $logger->fatal(__x("{filename}: invalid processor specification for '{$suffix}'",
                                   filename => $filename,
                                   suffix => $suffix));
        	}
        	$record->{suffix} = lowercase $record->{suffix};
        	$config->{processors}->{lowercase $suffix}
        	    = delete $config->{processors}->{$suffix};
        }
    }

    # Clean up certain variables or overwrite them unconditionally.
    $config->{srcdir} = Cwd::abs_path($config->{srcdir});
    $config->{outdir} = Cwd::abs_path($config->{outdir});
    
    return $self;
}

sub ignorePath {
    my ($self, $path) = @_;
    
    # We only care about regular files and directories.  Symbolic links are 
    # excluded on purpose.  If, however, the file is deleted, we have to
    # do the normal checks.
    if (-e $path && (!-f $path && !-d $path)) {
    	return $self;
    }

    # Do not ignore the top-level directory.  This check is needed because
    # abs2rel() returns a lone dot for it.
    return if $path eq $self->{srcdir};

    my $relpath = File::Spec->abs2rel($path, $self->{srcdir});
    
    # Ignore all underscore files and directories but only on the top-level.
    return $self if '_' eq substr $relpath, 0, 1;
    
    # Ignore all hidden files and directories.
    foreach my $part (File::Spec->splitdir($relpath)) {
        return $self if '.' eq substr $part, 0, 1;
    }
    
    return;
}

sub getProcessorSuffix {
	my ($self, $asset) = @_;
	
	my $suffix = $asset->{suffix};
	foreach my $key (keys %{$self->{processors}}) {
		if ($suffix =~ /^(?:$key)$/) {
			return $self->{processors}->{$key}->{suffix};
		}
	}
	
	return '';
}

sub getProcessor {
	my ($self, $asset) = @_;
	
	require Qgoda;
	my $logger = Qgoda->new->logger('config');
	
    my $suffix = $asset->{suffix};
    foreach my $key (keys %{$self->{processors}}) {
        if ($suffix =~ /^(?:$key)$/) {
            my $class = $self->{processors}->{$key}->{convertor} or next;
            $class = 'Qgoda::Convertor::' . $class;
            my $module = $class;
            $module =~ s{(?:::|')}{/}g;
            $module .= '.pm';
            eval { require $module };
            if ($@) {
                $logger->error($@);
                next;
            } else {
            	my $options = $self->{processors}->{$key}->{options} || {};
            	return $class->new(%$options);
            }
        }
    }

    return Qgoda::Convertor::Null->new;    
}

sub __isHash {
	my ($self, $what) = @_;
	
	return unless $what && ref $what && 'HASH' eq reftype $what;
	
	return $self;
}

1;
