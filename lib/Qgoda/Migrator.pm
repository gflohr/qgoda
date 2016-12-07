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

package Qgoda::Migrator;

use strict;

use Locale::TextDomain qw(com.cantanea.qgoda);
use File::Path qw(remove_tree make_path);
use File::Spec;
use YAML::XS;

use Qgoda;
use Qgoda::Util qw(write_file);

sub new {
	my ($class) = @_;
	
	bless {}, $class;
}

sub logger {
	my ($self) = @_;
	
	my $prefix = ref $self;
    $prefix =~ s{^Qgoda::Migrator::}{Migrator::};
    
    return Qgoda->new->logger($prefix);
}

sub createOutputDirectory {
    my ($self) = @_;
    
    my $logger = $self->logger;
    my $out_dir = $self->outputDirectory;
    
    if (-e $out_dir) {
        $logger->info(__x("Removing output directory '{directory}'.",
                          directory => $out_dir));
        if (!$self->dryRun) {
            remove_tree $out_dir
                or $logger->fatal(__x("Cannot remove directory:"
                                      . " '{directory}': {error}!"));
        }
    }
    
    $logger->info(__x("Creating output directory '{directory}'.",
                      directory => $out_dir));
    if (!$self->dryRun) {
        make_path $out_dir
            or $logger->fatal(__x("Cannot create directory:"
                                  . " '{directory}': {error}!"));
    }
    
    return $self;
}

sub dryRun {
	Qgoda->new->getOption('nochange');
}

sub outputDirectory {
	shift->{_out_dir};
}

sub writeConfig {
	my ($self, $config) = @_;
	
	my $logger = $self->logger;
	
	my $out_dir = $self->outputDirectory;
	my $filename = File::Spec->catfile($out_dir, '_config.yaml');
	
	$logger->debug(__x("Writing configuration file '{filename}'.",
	                   filename => $filename));
	
	my $yaml = YAML::XS::Dump($config);
	if (!$self->dryRun) {
	    write_file $filename, $yaml 
	        or die __x("Error writing '{filename}': {error}.",
	                   filename => $filename, error => $!);
	}
	
	return $self;
}

sub logError {
	my ($self, $msg) = @_;
	
	$self->logger->error($msg);
	++$self->{_err_count};
	
	# This allows the construct $self->logError or return;
	return;
}

sub createDirectory {
	my ($self, $directory) = @_;

    return $self if -e $directory;
    
    my $logger = $self->logger;
    $logger->debug(__x("Creating directory '{directory}'.",
                       directory => $directory));
    
    return $self if $self->dryRun;
    
    make_path $directory 
        or return $self->logError(__x("Error creating '{directory}': {error}!",
                                      directory => $directory, error => $!));
    
    return $self;
}

1;
