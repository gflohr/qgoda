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

package Qgoda::Init::copy;

use strict;

#VERSION

use Locale::TextDomain qw('qgoda');
use File::Spec;
use File::Find qw(find);
use File::Copy qw(copy);

sub new {
	my ($class, $init) = @_;

	bless {
		__init => $init,
	}, $class;
}

sub run {
	my ($self, $config) = @_;

	my $q = Qgoda->new;
	my $logger = $q->logger;
	my $force = $self->{__init}->getOption('force');
	my $ignore_case = !$q->config->{'case-sensitive'};
	my @excludes = @{$config->{_exclude} || []};
	push @excludes, '/_config.yaml', '/_config.yml', '/_init.yaml', '/_init.yml';
	my $exclude = File::Globstar::ListMatch->new(\@excludes,
												 ignoreCase => $ignore_case);
	my $precious;
	if ($force < 2 && $config->{_precious}) {
		$precious = File::Globstar::ListMatch->new($config->{_precious});
	}

	$logger->info(__"copying files");
	if ($force) {
		$logger->info(__"option '--force' given, will overwrite files");
		if ($config->{_precious}) {
			if ($force > 1) {
				$logger->info(__"option '--force' given twice, will overwrite precious files");
			} else {
				$logger->info(__"but will preserve precious files, give '--force' twice to overwrite");
			}
		}
	} else {
		$logger->info(__"will preserve files, use '--force' to overwrite");
	}

	# Filter out entries that should be ignored.  This happens again in the
	# wanted function but it allows to bypass ignored directories completely.
	# This may come in handy if the directory contains '/node_modules'.
	my $preprocess = sub {
		my (@names) = @_;
		my $relpath = File::Spec->abs2rel($File::Find::dir, $config->{_srcdir});

		# Do not use File::Spec->catfile! Ignore patterns uses slashes only.
		return grep { !$exclude->match("$relpath/$_") } @names;
	};

	my $wanted = sub {
		return if '.' eq $_;
		return if '..' eq $_;

		my $relpath = File::Spec->abs2rel($File::Find::name, $config->{_srcdir});
		next if $exclude->match($relpath);

		if (-d $File::Find::name) {
			if (!-e $relpath) {
				$logger->debug(__x("create directory '{dir}'",
								   dir => $relpath));
				mkdir $relpath
					or $logger->fatal(__x("cannot create '{dir}': {error}",
										  dir => $relpath, error => $!));
			}

			return; # Done.
		}

		if (-e $relpath) {
			if (!$force) {
				$logger->info(__x("not overwriting '{file}' without '--force'",
								file => $relpath));
				return; # Done.
			}

			if ($precious && $precious->matchInclude($relpath)) {
				$logger->info(__x("not overwriting precious '{file}' without '--force --force'",
								  file => $relpath));
				return; # Done.
			}
		}

		# All tests passed, copy the file.
		$logger->debug(__x("copy '{src}' to '{dest}'",
						   src => $File::Find::name, dest => $relpath));
		copy $File::Find::name, $relpath
			or $logger->fatal(__x("cannot copy '{src}' to '{dest}': {error}",
								  src => $File::Find::name,
								  dest => $relpath,
								  error => $!));
	};

	find { wanted => $wanted, no_chdir => 1 }, $config->{_srcdir};

	return $self;
}

1;
