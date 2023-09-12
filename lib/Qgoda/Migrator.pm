#! /bin/false

# Copyright (C) 2016-2023 Guido Flohr <guido.flohr@cantanea.com>,
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

package Qgoda::Migrator::Jekyll;

use strict;

#VERSION

use Locale::TextDomain qw('qgoda');
use File::Find qw(find);
use File::Path qw(remove_tree);
use YAML::XS;

use Qgoda::Util qw(write_file);
use Qgoda::Util::FileSpec qw(catfile);

sub new {
	my ($class, $args, $global_options, %options) = @_;

	my @files;
	find(sub { push @files, $File::Find::name if !-d $_}, '.');

	my $self = bless {
		__config => {},
		__args => $args,
		__global_options => $global_options,
		__options => \%options,
		__files => \@files,
	}, $class;

	my $logger = $self->logger;

	foreach my $file (@files) {
		if ($file eq './.git/config') {
			$self->{__is_git} = 1;
		} elsif ($file =~ './_views/' || $file eq './_views'
		         || $file eq './_qgoda.yaml') {
			$logger->fatal(__x(
				"the file {file} is in the way and must be removed",
				file => $file
			));
		}
	}

	if ($options{remove}) {
		if (-d $options{output_directory}) {
			$logger->debug(__"recursively deleting output directory");
			remove_tree $options{output_directory}, \my $error;
			if ($error && @$error) {
				foreach my $diagnostics (@$error) {
					my ($filename, $message) = %$diagnostics;
					if ($filename eq '') {
						$logger->error(__x("error removing directory: {error}"));
					} else {
						$logger->error(__x(
							"error removing directory '{directory}: {error}\n",
							directory => $options{output_directory},
							error => $message,
						));
					}
				}
				$logger->fatal(__"cannot proceed after errors");
			}
		} elsif (-e $options{output_directory}) {
			$logger->debug("unlink output directory");
			unlink $options{output_directory}
				or die __x("error deleting '{file}': {error}",
				           file => $options{output_directory},
						   error => $!) . "\n";
		}
	}

	return $self;
}

sub settings {
	return;
}

sub logger {
	my ($self) = @_;

	return $self->{__logger} if exists $self->{__logger};

	my $prefix = ref $self;
	$prefix =~ s/^Qgoda::Migrator:://;
	$prefix = 'migrate][' . lc $prefix;

	return $self->{__logger} = Qgoda->new->logger($prefix);
}

sub args { shift->{__args} }

sub globalOptions { shift->{__global_options} }

sub options { shift->{__options} }

sub files { @{shift->{__files}} }

sub config { shift->{__config} }

sub writeConfig {
	my ($self) = @_;

	my $prefix =
		__x("Configuration automatically created by Qgoda {version}.",
		    version => $Qgoda::VERSION);
	my $yaml = YAML::XS::Dump($self->config);
	$yaml =~ s/^---[ \t*]\n//;

	return $self->writeFile('_qgoda.yaml', '# ' . $prefix . "\n" . $yaml);
}

sub writeFile {
	my ($self, $filename, $contents) = @_;

	my $path = catfile $self->options->{output_directory}, $filename;

	my $logger = $self->logger;
	$logger->debug(__x(
		"writing migrated file '{filename}'",
		filename => $filename,
	));
	write_file $path, $contents or $logger->fatal(__x(
		"cannot create '{filename}': {error}",
		filename => $path, error => $!
	));

	return $self;
}

1;
