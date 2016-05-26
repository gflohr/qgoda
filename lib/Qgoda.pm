#! /bin/false

package Qgoda;

use strict;

use base 'Exporter';
use vars qw(@EXPORT $qgoda $VERSION);
@EXPORT = qw($qgoda $VERSION);
$VERSION = '0.1.1';

use Locale::TextDomain qw(com.cantanea.qgoda);
use File::Find;
use YAML;

use Qgoda::Logger;
use Qgoda::Config;
use Qgoda::Site;
use Qgoda::Asset;
use Qgoda::Analyzer;
use Qgoda::Builder;

sub new {
    return $qgoda if $qgoda;

    my ($class, %options) = @_;

    my $self = $qgoda = bless {}, $class;

    while (my ($key, $value) = each %options) {
        $self->{'__' . $key} = $value;
    }

    $self->{__logger} = $self->logger;

    my $logger = $self->{__logger};
    $logger->info(__"initializing");
    
    $self->{__config} = Qgoda::Config->new;
    $self->{__analyzers} = [Qgoda::Analyzer->new];
    $self->{__builders} = [Qgoda::Builder->new];

    return $qgoda;
}

sub build {
    my ($self) = @_;

    my $logger = $self->{__logger};
    my $config = $self->{__config};
    
    $logger->info(__"start building site");
    
    chdir $self->{__config}->{srcdir} 
        or $logger->fatal(__x("cannot chdir to source directory '{dir}': {error}",
                              dir => $config->{srcdir},
                              error => $!));
    my $site = Qgoda::Site->new($config);

    $self->{__outfiles} = [];    
    $self->__scan($site);
    
    $self->__analyze($site);
    $self->__build($site);
    
    $self->__prune($site);
    
    my $num_artefacts = $site->getArtefacts;
    $logger->info(__nx("finished building site with one artefact",
                       "finished building site with {num} artefacts",
                       $num_artefacts,
                       num => $num_artefacts));

    return $self; 
}

sub watch {
    my ($self) = @_;

    my $logger = $self->{__logger};

    my $init;
    
    eval {
    	my $config = $self->{__config};
    	
        require Filesys::Notify::Simple;
        my $watcher = Filesys::Notify::Simple->new([$config->{srcdir}]);
        while (1) {
        	if ($init) {
                $logger->debug(__x("waiting for changes in '{dir}'", 
                                   dir => $config->{srcdir}));

                my @files;
                $watcher->wait(sub {
                    foreach my $event (@_) {
                    	if ($config->ignorePath($event->{path})) {
                    	    $logger->debug(__x("changed file '{filename}' is ignored",
                	                          filename => $event->{path}));
                	       next;
                	    }
                        $logger->debug(__x("file '{filename}' has changed",
                                           filename => $event->{path}));
                        push @files, $event->{path};
                    }
                });

                next if !@files;
        	}
            $logger->info(__"start rebuilding site because of file system change")
                if $init;
            $init = 1;
            eval { $self->build };
            $logger->error($@) if $@;
        }
    };
    $logger->fatal($@) if $@;
}

sub logger {
    my ($self, $prefix) = @_;

    my %args = (prefix => $prefix);
    if ($self->{__verbose}) {
        $args{debug} = 1;
    } elsif ($self->{__quiet}) {
        $args{quiet} = 1;
    }

    return Qgoda::Logger->new(%args);
}

sub config {
	shift->{__config};
}

sub dumpConfig {
	my ($self) = @_;
	
	# Make a shallow copy so that we unbless the reference.
	my %config = %{$self->{__config}};
	print YAML::Dump(\%config);
	
	return $self;
}

# FIXME! This should instantiate scanner plug-ins and use them instead.
sub __scan {
	my ($self, $site) = @_;
	
	my $logger = $self->{__logger};
	my $config = $self->{__config};
	
	my $outdir = $config->{outdir};
	my $srcdir = $config->{srcdir};
	
	# Scan the source directory.
    $logger->debug(__x("scanning source directory '{srcdir}'", 
                       srcdir => $config->{srcdir}));
	File::Find::find({
		wanted => sub {
		    if (-f $_) {
			    my $path = Cwd::abs_path($_);
			    if (!$config->ignorePath($path)) {
			    	my $relpath = File::Spec->abs2rel($path, $config->{srcdir});
			    	my $asset = Qgoda::Asset->new($path, $relpath);
			    	$site->addAsset($asset);
			    }
		    }
		},
		preprocess => sub {
			# Prevent descending into ignored directories.
			my $path = Cwd::abs_path($File::Find::dir);
			if ($config->ignorePath($path)) {
				return;
			} else {
				return @_;
			}
		}
	}, $config->{srcdir});
	
    # And the output directory.
    my @outfiles;
    $self->{__outfiles} = \@outfiles;
    $logger->debug(__x("scanning output directory '{outdir}'", 
                       outdir => $config->{outdir}));
    File::Find::find(sub {
    	if ($_ ne '.' && $_ ne '..') {
            push @outfiles, Cwd::abs_path($_);
    	}
    }, $config->{outdir});
    
	return $self;
}

sub __analyze {
	my ($self, $site) = @_;
	
    foreach my $analyzer (@{$self->{__analyzers}}) {
    	$analyzer->analyze($site);
    }
    
    return $self;
}

sub __build {
	my ($self, $site) = @_;
	
	foreach my $builder (@{$self->{__builders}}) {
		$builder->build($site);
	}
	
	return $self;
}

# FIXME! This should instantiate plug-ins and use them instead.
sub __prune {
	my ($self, $site) = @_;
	
	warn;
	return;
	
	# Sort the output files by length first.  That ensures that we do a 
	# depth first clean-up.
	my @outfiles = sort {
	   length($b) <=> length($a)
	} @{$self->{__outfiles}};
	
	my $logger = $self->{__logger};
	my %directories;
	
	foreach my $outfile (@outfiles) {
		if ($directories{$outfile} || $site->getArtefact($outfile)) {
			# Mark the containing directory as generated.
			my ($volume, $directory, $filename) = File::Spec->splitpath($outfile);
			my $container = File::Spec->catpath($volume, $directory, '');
			$container =~ s{/$}{};
			$directories{$container} = 1;
		} elsif (-d $outfile) {
			$logger->error(__x("cannot remove directory '{directory}': {error}",
			                   directory => $outfile, error => $!))
			    if !rmdir $outfile;
		} else {
            $logger->error(__x("cannot remove file '{filename}': {error}",
                               filename => $outfile, error => $!))
                if !unlink $outfile;
		}
	}
	
	return $self;
}

1;
