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

package Qgoda::Init;

use strict;

use Locale::TextDomain qw('qgoda');
use File::Spec;
use JSON '2.90';
use Scalar::Util qw(weaken reftype);

use Qgoda::Util qw(read_file write_file yaml_error perl_class safe_yaml_load);
use Qgoda::Repository;

sub new {
    my ($class, $args, %options) = @_;

    my $q = Qgoda->new;
    my $uri = @$args ? $args->[0] : 'http://github.com/gflohr/qgoda-default';
    my $self = {
        __logger => $q->logger,
        __force => $options{force},
        __config => $q->config,
        __uri => $uri,
        __options => \%options,
    };

    bless $self, $class;
}

sub init {
    my ($self) = @_;

    my $logger = $self->{__logger};
    my $config = $self->{__config};

    my $repo = Qgoda::Repository->new($self->{__uri});
    my ($dir, $tmp) = $repo->fetch;

    my $init_yaml = File::Spec->catfile($dir, '_init.yaml');
    $init_yaml = File::Spec->catfile($dir, '_init.yml')
        if !-e $init_yaml;
    my $init;
    if (-e $init_yaml) {
        $init = $self->__readInitYAML($init_yaml);
    } else {
        $logger->warning(__"Neither '_init.yaml' nor '_init.yml'  found in"
                           . " repository, proceding with defaults");
        return {};
    }

    $init->{_srcdir} = $dir;

    my $tasks = $init->{_tasks} || [];
    unshift @$tasks, 'copy', 'config';
    my %skip = map { $_ => 1 } @{$self->getOption('skip')};
    foreach my $task (@$tasks) {
        next if $skip{$task};
        if (!perl_class $task) {
            $logger->fatal(__x("Invalid task name '{name}'",
                               name => $task));
        }
        my $class = 'Qgoda::Init::' . $task;
        my $module = $class;
        $module =~ s{::}{/}g;
        $module .= '.pm';
        eval { require $module };
        $logger->fatal(__x(("Cannot load task runner '{name}': {error}",
                            name => $task, error => $@)))
            if $@;
    }

    foreach my $task (@$tasks) {
        next if $skip{$task};
        my $class = 'Qgoda::Init::' . $task;
        my $weak = $self;
        weaken $weak;
        my $runner = $class->new($weak);
        $runner->run($init);
    }

    $config = Qgoda->new->config;
    my @helpers = keys %{$config->{helpers}};
    if (@helpers) {
        $logger->warning(__"IMPORTANT! The following external helper program"
                           . " will be automatically started by Qgoda:");
        $logger->warning('-' x 30);
        foreach my $helper (@helpers) {
            my $args = $config->{helpers}->{$helper};
            $args = [$args] unless ref $args && 'ARRAY' eq reftype $args;
            my @pretty;
            foreach my $arg (@$args) {
                if ($arg =~ s{[\\\"]}{\\$1}) {
                    $arg =~ qq{"$arg"};
                }
                push @pretty, $arg;
            }
            my $pretty = join ' ', @pretty;
            $logger->safeWarning("  $pretty");
        }
        $logger->warning('-' x 30);
        $logger->warning(__"Please review the above list before you start qgoda!");
    }

    return $self;
}

sub getOption {
    my ($self, $option) = @_;

    return $self->{__options}->{$option};
}

sub __readInitYAML {
    my ($self, $path) = @_;

    my $logger = $self->{__logger};
    my $yaml = read_file $path;
    if (!defined $yaml) {
        $logger->fatal(__x("error reading file '{filename}': {error}",
                           filename => $path, error => $!));
    }

    my $data = eval { safe_yaml_load $yaml };
    $logger->fatal(yaml_error $path, $@) if $@;

    return $data;
}

sub command(@) {
    my ($self, @args) = @_;

    my @pretty;
    foreach my $arg (@args) {
        my $pretty = $arg;
        $pretty =~ s{(["\\])}{\\$1}g;
        $pretty = qq{"$pretty"} if $pretty =~ /[ \t]/;
        push @pretty, $pretty;
    }

    my $q = Qgoda->new;
    my $logger = $q->logger;

    my $pretty = join ' ', @pretty;
    $logger->info(__x("Running '{command}':", command => $pretty));

    if (0 != system @args) {
        $logger->error(__x("Running '{command}' failed: {error}",
                       command => $pretty, error => $!));
        return;
    }

    return $self;
}

sub __mkdir {
    my ($self, $directory) = @_;

    return $self if -e $directory;

    my $q = Qgoda->new;
    my $logger = $q->logger;

    $logger->info(__x("Creating directory '{directory}.",
                      directory => $directory));

    mkdir $directory
        or $logger->fatal(__x("Error creating directory '{dir}': {error}!",
                              dir => $directory, error => $!));

    return $self;
}

sub __write {
    my ($self, $filename, $content) = @_;

    my $q = Qgoda->new;
    my $logger = $q->logger;
    my $config = $q->config;

    if (-e $filename && !$self->{__force}) {
        $logger->warning(__x("Not overwriting '{filename}'!",
                             filename => $filename));
        return $self;
    }

    $content =~ s/\@([^\@]+)\@/$config->{$1}/g;

    $logger->info(__x("Initializing '{filename}'.", filename => $filename));

    open my $fh, '>', $filename
        or $logger->fatal(__x("Cannot write '{filename}': {error}!\n",
                              filename => $filename, error => $!));
    print $fh $content;
    close $fh
        or $logger->fatal(__x("Cannot write '{filename}': {error}!\n",
                              filename => $filename, error => $!));

    return $self;
}

sub __trim {
    my ($self, $content) = @_;

    $content =~ s/\n+$/\n/;

    return $content;
}

1;

=head1 NAME

Qgoda::Init - Initialize Qgoda site in current directory.
