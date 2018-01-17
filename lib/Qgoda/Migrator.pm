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

use Locale::TextDomain qw(qgoda);
use File::Path qw(remove_tree make_path);
use File::Spec;
use File::Copy::Recursive qw(rcopy);
use YAML::XS;
use Hook::LexWrap;

use Qgoda;
use Qgoda::Util qw(write_file);

sub new {
    my ($class, %options) = @_;

    my $self = {};
    foreach my $option (keys %options) {
        $option = '__' . $option;
        $option =~ s/-/_/g;
        $self->{$option} = $options{$option};
    }
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
    shift->{__dry_run};
}

sub outputDirectory {
    shift->{__output_directory};
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

    # This allows the construct return $self->logError.
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
        or return $self->logError(__x("Error creating directory '{directory}': {error}!",
                                      directory => $directory, error => $!));

    return $self;
}

sub createFile {
    my ($self, $path, $data) = @_;

    my ($volume, $directory, $filename) = File::Spec->splitpath($path);
    $self->createDirectory(File::Spec->catpath($volume, $directory));

    write_file $path, $data
        or $self->logError(__x("Error creating file '{file}': {error}!",
                               file => $path, error => $!));

    return $self;
}

sub markFileDone {
    my ($self, @files) = @_;

    $self->{_files_done} ||= {};

    foreach my $file (@files) {
        $self->{_files_done}->{$file} = 1;
    }

    return $self;
}

sub copyUndone {
    my ($self, $fcopy) = @_;

    my $logger = $self->logger;
    $logger->info(__"Copying all other files as is.");

    $self->{_files_done}->{$self->{_out_dir}} = 1;

    opendir my $dh, $self->{_src_dir}
        or return $self->logError(__x("Error opening directory '{directory}':"
                                      . " {error}!\n"));
    my @files = grep {
        !$self->{_files_done}->{$_};
    } grep {
        $_ ne '.';
    } grep {
        $_ ne '..';
    } readdir $dh;

    $fcopy ||= sub { return $_[-1] };

    my $lexical_wrapper = wrap 'File::Copy::Recursive::fcopy', post => $fcopy;

    foreach my $file (@files) {
        $logger->debug(__x("Copying '{file}'.",
                            file => $file));
         my $dest = File::Spec->catfile($self->{_out_dir}, $file);
         rcopy $file, $dest
             or $self->logError(__x("Error copying '{file}' to '{dest}':"
                                    . " {error}!\n",
                                    file => $file,
                                    dest => $dest,
                                    error => $!));
    }

    return $self;
}

1;
