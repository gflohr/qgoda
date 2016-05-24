#! /bin/false

package Qgoda::Config;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');
use File::Spec;
use YAML;
use Cwd;
use Scalar::Util qw(reftype);

use Qgoda::Util qw(read_file empty yaml_error merge_data lowercase);

my %converters;

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

    # Default configuration.
    my $config = {
    	title => __"A New Qgoda Powered Site",
    	srcdir => '.',
    	converters => {
            chains => {
                markdown => {
                	modules => [qw(Markdown HTML)],
                	suffix => 'html',
                },
                html => {
                	modules => 'HTML',
                },
            },
            suffixes => {
                md => 'markdown',
                mdown => 'markdown',
                mkdn => 'markdown',
                mdwn => 'markdown',
                mkd => 'markdown',
                html => 'html',
                htm => 'html',
            },
            modules => {
                Markdown => 'Markdown',
                HTML => 'Template::Toolkit',
            },
            options => {
                Markdown => []
            },
    	},
    };
    
    if (!empty $filename) {
        $logger->info(__x("reading configuration from '{filename}'",
                          filename => '_config.yaml'));
        my $yaml = read_file $filename;
        if (!defined $yaml) {
        	$logger->fatal(__x("error reading file '{filename}': {error}",
        	                   filename => $filename, error => $!));
        }
        my $local = eval { YAML::Load($yaml) };
        $logger->fatal(yaml_error $filename, $@) if $@;
        $config = merge_data $config, $local;
    }
    my $self = bless $config, $class;

    eval { $self->checkConfig($self) };
    if ($@) {
        $logger->fatal(__x("{filename}: {error}",
                           filename => $filename, error => $@));
    }
    
    # Fill in defaults and consistency checks.
    $config->{outdir} = File::Spec->catpath($config->{srcdir}, '_site')
        if empty $config->{outdir};

    # Clean up certain variables or overwrite them unconditionally.
    $config->{srcdir} = Cwd::abs_path($config->{srcdir});
    $config->{outdir} = Cwd::abs_path($config->{outdir});
    
    return $self;
}

# Consistency check.
sub checkConfig {
	my ($self, $config) = @_;
	
	die __"invalid format (not a hash)\n"
	    unless ($self->__isHash($config));
	die __x("'{variable}' must be a dictionary", variable => 'converters')
	    unless $self->__isHash($config->{converters});
    die __x("'{variable}' must be a dictionary", variable => 'converters.chains')
        unless $self->__isHash($config->{converters}->{chains});
    foreach my $chain (keys %{$config->{converters}->{chains}}) {
        die __x("'{variable}' must be a dictionary", variable => "converters.chains.$chain")
            unless $self->__isHash($config->{converters}->{chains}->{$chain});
        if (exists $config->{converters}->{chains}->{$chain}->{modules}) {
            die __x("'{variable}' must not be a dictionary", variable => "converters.chains.$chain.modules")
                if $self->__isHash($config->{converters}->{chains}->{$chain}->{modules});
            if (!$self->__isArray($config->{converters}->{chains}->{$chain}->{modules})) {
                $config->{converters}->{chains}->{$chain}->{modules} =
                    [$config->{converters}->{chains}->{$chain}->{modules}],
            }
        } else {
            $config->{converters}->{chains}->{$chain}->{modules} = ['Null'];
        };
        if (exists $config->{converters}->{chains}->{$chain}->{suffix}) {
            die __x("'{variable}' must be a single value", variable => "converters.chains.$chain.suffix")
                if ref $config->{converters}->{chains}->{$chain}->{suffix};
        }
    }
    die __x("'{variable}' must be a dictionary", variable => 'converters.suffixes')
        unless $self->__isHash($config->{converters}->{suffixes});
    foreach my $suffix (keys %{$config->{converters}->{suffixes}}) {
    	my $lc_suffix = lowercase $suffix;
    	$config->{converters}->{suffixes}->{$lc_suffix}
    	     = delete $config->{converters}->{suffixes}->{$suffix};
        $suffix = $lc_suffix;
    	my $chain = $config->{converters}->{suffixes}->{$suffix};
        die __x("converter chain suffix '{suffix}' references undefined chain '{chain}'",
                suffix => $suffix, chain => $chain)
            unless exists $config->{converters}->{chains}->{$chain};
    }
    die __x("'{variable}' must be a dictionary", variable => 'converters.modules')
        unless $self->__isHash($config->{converters}->{modules});
    foreach my $module (keys %{$config->{converters}->{modules}}) {
        die __x("'{variable}' must be a scalar", variable => "converters.chains.$module")
            if ref $config->{converters}->{modules}->{$module};
        die __x("'{variable}' must not be empty", variable => "converters.chains.$module")
            if empty $config->{converters}->{modules}->{$module};
    }
    die __x("'{variable}' must be a dictionary", variable => 'converters.options')
        unless $self->__isHash($config->{converters}->{options});
        
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

sub getConverterChain {
	my ($self, $asset) = @_;
	
	return $asset->{chain} if exists $asset->{chain};
	
	my $suffix = $asset->{suffix};
	return if empty $asset->{suffix};
	
    my @suffixes = reverse split /^\./, $asset->{suffix};
    foreach my $suffix (@suffixes) {
        if ($self->{converters}->{suffixes}->{$suffix}) {
            return $self->{converters}->{suffixes}->{$suffix};
        }
    }
    
    return;
}

sub getConvertedSuffix {
    my ($self, $asset) = @_;
    
    return if empty $asset->{suffix};
    my @suffixes = reverse split /^\./, $asset->{suffix};
    foreach my $suffix (@suffixes) {
    	if ($self->{converters}->{suffixes}->{$suffix}) {
    		my $chain = $self->{converters}->{suffixes}->{$suffix};
    		$suffix = $self->{converters}->{chains}->{$chain}->{suffix};
    		return if empty $suffix;
    		
    	    return join '.', reverse @suffixes;
    	}
    }
    
    return;
}

sub getConverters {
	my ($self, $asset) = @_;
	
	require Qgoda;
	my $logger = Qgoda->new->logger('config');

    # Read the converter chain from the asset if 
    my $chain = $asset->{chain};
	
=cut
    my $suffix = $asset->{suffix};
    foreach my $key (keys %{$self->{converters}->{suffixes}}) {
    	
        if ($suffix =~ /^(?:$key)$/) {
            my $class = $self->{converters}->{$key}->{converter} or next;
            my $options = $self->{options}->{converters}->{$class} || {};
            $class = 'Qgoda::Converter::' . $class;
            my $module = $class;
            $module =~ s{(?:::|')}{/}g;
            $module .= '.pm';
            eval { require $module };
            if ($@) {
                $logger->error($@);
                next;
            } else {
            	return $class->new(%$options);
            }
        }
    }
=cut

    return [];
}

sub getProcessor {
	my ($self, $asset, $site) = @_;
	
	my $config = $site->{config};
	my $class = $asset->{processor};
	$class = $site->{config}->{processor} if empty $class;
	$class = 'Null' if emtpy $class;
	my $full_class = ''
}

sub __isHash {
    my ($self, $what) = @_;
    
    return unless $what && ref $what && 'HASH' eq reftype $what;
    
    return $self;
}

sub __isArray {
    my ($self, $what) = @_;
    
    return unless $what && ref $what && 'ARRAY' eq reftype $what;
    
    return $self;
}

1;
