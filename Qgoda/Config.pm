#! /bin/false

package Qgoda::Config;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');
use File::Spec;
use YAML;
use Cwd;
use Scalar::Util qw(reftype);

use Qgoda::Util qw(read_file empty yaml_error merge_data);
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

    # Default configuration.
    my $config = {
    	title => __"A New Qgoda Powered Site",
    	srcdir => '.',
    	convertors => {
            chains => {
                markdown => {
                	modules => [qw(Markdown HTML)],
                	suffix => 'html',
                },
                html => {
                	modules => 'HTML',
                	suffix => 'html',
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
	die __x("'{variable}' must be a dictionary", variable => 'convertors')
	    unless $self->__isHash($config->{convertors});
    die __x("'{variable}' must be a dictionary", variable => 'convertors.chains')
        unless $self->__isHash($config->{convertors}->{chains});
    foreach my $chain (keys %{$config->{convertors}->{chains}}) {
        die __x("'{variable}' must be a dictionary", variable => "convertors.chains.$chain")
            unless $self->__isHash($config->{convertors}->{chains}->{$chain});
        if (exists $config->{convertors}->{chains}->{$chain}->{modules}) {
            die __x("'{variable}' must not be a dictionary", variable => "convertors.chains.$chain.modules")
                if $self->__isHash($config->{convertors}->{chains}->{$chain}->{modules});
            if (!$self->__isArray($config->{convertors}->{chains}->{$chain}->{modules})) {
                $config->{convertors}->{chains}->{$chain}->{modules} =
                    [$config->{convertors}->{chains}->{$chain}->{modules}],
            }
        } else {
            $config->{convertors}->{chains}->{$chain}->{modules} = ['Null'];
        };
        if (exists $config->{convertors}->{chains}->{$chain}->{suffix}) {
            die __x("'{variable}' must be a single value", variable => "convertors.chains.$chain.suffix")
                if ref $config->{convertors}->{chains}->{$chain}->{suffix};
        }
    }
    die __x("'{variable}' must be a dictionary", variable => 'convertors.suffixes')
        unless $self->__isHash($config->{convertors}->{suffixes});
    foreach my $suffix (keys %{$config->{convertors}->{suffixes}}) {
    	my $chain = $config->{convertors}->{suffixes}->{$suffix};
        die __x("convertor chain suffix '{suffix}' references undefined chain '{chain}'",
                suffix => $suffix, chain => $chain)
            unless exists $config->{convertors}->{chains}->{$chain};
    }
    die __x("'{variable}' must be a dictionary", variable => 'convertors.modules')
        unless $self->__isHash($config->{convertors}->{modules});
    foreach my $module (keys %{$config->{convertors}->{modules}}) {
        die __x("'{variable}' must be a scalar", variable => "convertors.chains.$module")
            if ref $config->{convertors}->{modules}->{$module};
        die __x("'{variable}' must not be empty", variable => "convertors.chains.$module")
            if empty $config->{convertors}->{modules}->{$module};
    }
    die __x("'{variable}' must be a dictionary", variable => 'convertors.options')
        unless $self->__isHash($config->{convertors}->{options});
        
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

sub getConvertorSuffix {
	my ($self, $asset) = @_;
	
	my $suffix = $asset->{suffix};
	foreach my $key (keys %{$self->{convertors}}) {
		if ($suffix =~ /^(?:$key)$/) {
			return $self->{convertors}->{$key}->{suffix};
		}
	}
	
	return '';
}

sub getConvertor {
	my ($self, $asset) = @_;
	
	require Qgoda;
	my $logger = Qgoda->new->logger('config');
	
    my $suffix = $asset->{suffix};
    foreach my $key (keys %{$self->{convertors}}) {
        if ($suffix =~ /^(?:$key)$/) {
            my $class = $self->{convertors}->{$key}->{convertor} or next;
            my $options = $self->{options}->{convertors}->{$class} || {};
            $class = 'Qgoda::Convertor::' . $class;
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

    return Qgoda::Convertor::Null->new;    
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
