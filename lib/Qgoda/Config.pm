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

package Qgoda::Config;

use strict;

#VERSION

use Locale::TextDomain qw('qgoda');

use Scalar::Util qw(reftype looks_like_number);
use File::Globstar qw(quotestar);
use File::Globstar::ListMatch;
use Storable qw(dclone);
use Cwd qw(realpath);
use Encode;
use boolean;
use Qgoda::Util qw(read_file empty yaml_error merge_data lowercase
				   safe_yaml_load);
use Qgoda::Util::FileSpec qw(absolute_path abs2rel canonical_path);
use Qgoda::JavaScript::Environment;
use Qgoda::Schema;

my %processors;

sub new {
	my ($class, %args) = @_;

	require Qgoda;
	my $q = Qgoda->new;
	my $logger = $q->logger('config');

	$DB::single = 1;
	my $filename;
	if (!empty $args{filename}) {
		$filename = $args{filename};
	} elsif (-e '_qgoda.yaml') {
		$filename = '_qgoda.yaml';
	} elsif (-e '_qgoda.yml') {
		$filename = '_qgoda.yml';
	} elsif (-e '_qgoda.json') {
		$filename = '_qgoda.json';
	} elsif (!$q->getOption('no-config')) {
		$logger->warning(__"config file '_qgoda.yaml' not found, "
		                 . "proceeding with defaults.");
		if (-e '_config.yaml') {
			$logger->warning(__x("do you have to rename '_config.{extension}' "
			                     . "to '_qgoda'.{extension}?",
			                     extension => 'yaml'));
		} elsif (-e '_config.yml') {
			$logger->warning(__x("do you have to rename '_config.{extension}' "
			                     . "to '_qgoda'.{extension}?",
			                     extension => 'yml'));
		} elsif (-e '_config.json') {
			$logger->warning(__x("do you have to rename '_config.{extension}' "
			                     . "to '_qgoda'.{extension}?",
			                     extension => 'json'));
		}
	}

	my $yaml = '';
	if (!empty $filename) {
		$logger->info(__x("reading configuration from '{filename}'",
						  filename => $filename));
		$yaml = read_file $filename;
		if (!defined $yaml) {
			$logger->fatal(__x("cannot read '{filename}': {error}",
							   filename => $filename, error => $!));
		}
		Encode::_utf8_on($yaml);
	}

	my $local_filename;
	if (-e '_localqgoda.yaml') {
		$local_filename = '_localqgoda.yaml';
	} elsif (-e '_localqgoda.yml') {
		$local_filename = '_localqgoda.yml';
	} elsif (-e '_localqgoda.json') {
		$local_filename = '_localqgoda.json';
	} elsif (-e '_localqgoda.yaml') {
		$logger->warning(__x("do you have to rename '_localqgoda.{extension}' "
		                     . "to '_localqgoda'.{extension}?",
		                     extension => 'yaml'));
	} elsif (-e '_localqgoda.yml') {
		$logger->warning(__x("do you have to rename '_localqgoda.{extension}' "
		                     . "to '_localqgoda'.{extension}?",
		                     extension => 'yaml'));
	} elsif (-e '_localqgoda.json') {
		$logger->warning(__x("do you have to rename '_localqgoda.{extension}' "
		                     . "to '_localqgoda'.{extension}?",
		                     extension => 'yaml'));
	}

	my $local_yaml = '';
	if (!empty $local_filename) {
		$logger->info(__x("reading local configuration from '{filename}'",
						  filename => $local_filename));
		$local_yaml = read_file $local_filename;
		if (!defined $yaml) {
			$logger->fatal(__x("cannot read '{filename}': {error}",
							   filename => $local_filename, error => $!));
		}
		Encode::_utf8_on($yaml);
	}

	my $jsfile = 'Qgoda/JavaScript/config.js';
	require $jsfile;
	my $code = Qgoda::JavaScript::config->code;
	my $node_modules = $q->nodeModules;
	my $js = Qgoda::JavaScript::Environment->new(global => $node_modules, no_console => 1);
	my $schema = Qgoda::Schema->config;
	$js->vm->set(schema => $schema);
	$js->vm->set(input => $yaml);
	$js->vm->set(local_input => $local_yaml);
	$js->vm->set(filename => $filename);
	$js->vm->set(local_filename => $local_filename);
	$js->run($code);

	my $exchange = $js->vm->get('__perl__');
	my $invalid = $exchange->{output}->{errors};
	if ($invalid) {
		my ($filename, $errors) = @$invalid;
		my $msg = '';
		if (ref $errors && 'ARRAY' eq ref $errors) {
			foreach my $error (@$errors) {
				$msg .= __x("{filename}: CONFIG{dataPath}: ",
							 filename => $filename,
							 dataPath => $error->{dataPath});
				$msg .= "$error->{message}\n";
				my $params = $error->{params};
				foreach my $param (keys %{$params || {}}) {
					$msg .= "\t$param: $params->{$param}\n";
				}
			}
		} else {
			$msg = "$filename: $errors\n";
		}

		die $msg;
	}

	my $config = $js->vm->get('config');

	my $self = bless $config, $class;

	# Clean up certain variables or overwrite them unconditionally.
	$config->{srcdir} = absolute_path;
	$config->{paths}->{site} =
		canonical_path(absolute_path(realpath($config->{paths}->{site})));
	$config->{paths}->{views} = canonical_path($config->{paths}->{views});

	$config->{po}->{tt2} = [$config->{paths}->{views}]
		if 0 == @{$config->{po}->{tt2}};

	# This outsmarts the default options for JSON schema.
	my $processor_options = $schema->{properties}
							->{processors}->{properties}
							->{options}->{default};
	$config->{processors}->{options} =
			merge_data $processor_options, $config->{processors}->{options};
	my $processor_chains = $schema->{properties}
							->{processors}->{properties}
							->{chains}->{default};
	$config->{processors}->{chains} =
			merge_data $processor_chains, $config->{processors}->{chains};

	my @exclude = (
		'/_*',
		'.*'
	);
	my @exclude_watch = (
		'/_*',
		'.*',
	);

	my $viewdir = abs2rel($self->{paths}->{views});
	push @exclude_watch, '!' . quotestar $viewdir
		if $viewdir !~ m{^\.\./};
	my $includedir = abs2rel($self->{paths}->{includes});
	push @exclude_watch, '!' . quotestar $includedir
		if $includedir !~ m{^\.\./};

	my @config_exclude = @{$config->{exclude} || []};
	my @config_exclude_watch = @{$config->{'exclude-watch'} || $config->{exclude} || []};

	push @exclude, @config_exclude;
	push @exclude_watch, @config_exclude_watch;
	my @precious = @{$config->{precious} || []};

	my $outdir = abs2rel($self->{outdir}, $self->{srcdir});
	if ($outdir !~ m{^\.\./}) {
		push @exclude, quotestar $outdir, 1;
		push @exclude_watch, quotestar $outdir, 1;
	}
	unless ($args{raw}) {
		$self->{__q_exclude} = File::Globstar::ListMatch->new(
			\@exclude,
			ignoreCase => !$self->{'case-sensitive'}
		);
		$self->{__q_exclude_watch} = File::Globstar::ListMatch->new(
			\@exclude_watch,
			ignoreCase => !$self->{'case-sensitive'}
		);
		$self->{__q_precious} = File::Globstar::ListMatch->new(
			\@precious,
			ignoreCase => !$self->{'case-sensitive'}
		);

		$self->{defaults} = $self->__compileDefaults($self->{defaults});
	}

	return $self;
}

sub ignorePath {
	my ($self, $path, $watch) = @_;

	# We only care about regular files and directories.  Symbolic links are
	# excluded on purpose.  If, however, the file is deleted, we have to
	# do the normal checks.
	if (-e $path && (!-f $path && !-d $path)) {
		return $self;
	}

	# Do not ignore the top-level directory.  This check is needed because
	# abs2rel() returns a lone dot for it.
	return if $path eq $self->{srcdir};

	my $relpath = abs2rel($path, $self->{srcdir});

	if ($watch) {
		return $self if $self->{__q_exclude_watch}->match($relpath);
	} else {
		return $self if $self->{__q_exclude}->match($relpath);
	}
	return;
}

sub __compileDefaults {
	my ($self, $rules) = @_;

	my @defaults;
	foreach my $rule (@$rules) {
		my $pattern = $rule->{files};
		# FIXME! This should be done by ajv?
		if (empty $pattern) {
			$pattern = ['*'];
		} elsif (!ref $pattern) {
			$pattern = [$pattern];
		}

		$pattern = File::Globstar::ListMatch->new($pattern,
												  !$self->{'case-sensitive'});
		# Same here.. The default {} should be inserted by ajv.
		my $values = dclone $rule->{values} if exists $rule->{values};
		push @defaults, [$pattern, $values || {}];
	}

	return \@defaults;
}

1;
