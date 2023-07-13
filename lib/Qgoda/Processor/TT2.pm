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

package Qgoda::Processor::TT2;

use strict;

#VERSION

use Template;
use Locale::TextDomain qw(qgoda);
use File::Spec;

use Qgoda::Util qw(empty);

use base qw(Qgoda::Processor);

my %instances;

sub new {
	my ($class, %options) = @_;

	my $self = bless {}, $class;
	$self->{__options} = \%options;

	require Qgoda;
	my $qgoda = Qgoda->new;
	my $config = $qgoda->config;
	my $srcdir = $config->{srcdir};
	my $viewdir = $config->{paths}->{views};

	# FIXME! Merge options with those from the configuration!
	my $scm = $config->{scm};
	my %options = (
		INCLUDE_PATH => [File::Spec->join($srcdir, $viewdir)],
		PLUGIN_BASE => ['Qgoda::TT2::Plugin'],
		RECURSION => 1,
		# Needed for qgoda po pot
		RELATIVE => 1,
		ENCODING => 'utf-8',
	);
	my $provider = $self->{__provider} = Qgoda::Template::Provider->new(
		%options,
		git_enabled => !empty $scm && 'git' eq $scm,
	);
	$options{LOAD_TEMPLATES} = [$provider];

	$self->{__tt} = Template->new({
		%options
	}) or die Template->error;

	return $self;
}

sub process {
	my ($self, $content, $asset, $filename) = @_;

	require Qgoda;
	my $qgoda = Qgoda->new;
	my $srcdir = $qgoda->config->{srcdir};
	my $viewdir = $qgoda->config->{paths}->{views};
	my $absviewdir = File::Spec->rel2abs($viewdir, $srcdir);
	my $gettext_filename = File::Spec->abs2rel($filename, $absviewdir);
	my $vars = {
		asset => $asset,
		config => Qgoda->new->config,
		gettext_filename => $gettext_filename,
	};

	my $cooked;
	$self->{__provider}->{__asset} = $asset;
	$self->{__tt}->process(\$content, $vars, \$cooked)
		or die $self->{__tt}->error, "\n" if !defined $cooked;

	return $cooked;
}

package Qgoda::Template::Provider;

use strict;

#VERSION

use Template::Constants;
use Locale::TextDomain qw(qgoda);

use base qw(Template::Provider);

sub new {
	my ($class, %options) = @_;

	my $git_enabled = delete $options{git_enabled};
	my $self = $class->SUPER::new(%options);
	$self->{__git_enabled} = $git_enabled;

	return $self;
}

sub fetch {
	my ($self, $name) = @_;

	if (!ref $name) {
		my $is_absolute;
		my $path;

		if (File::Spec->file_name_is_absolute($name)) {
			$is_absolute = 1;
			$path = $name if -e $name;
		} elsif ($name !~ m/$Template::Provider::RELATIVE_PATH/o) {
			foreach my $search (@{$self->{INCLUDE_PATH}}) {
				my $try = File::Spec->catfile($search, $name);
				if (-e $try) {
					$path = $try;
					$is_absolute = File::Spec->file_name_is_absolute($path);
					last;
				}
			}
		}

		if (defined $path) {
			my $qgoda = Qgoda->new;
			if ($self->{__git_enabled}
			    && !$qgoda->versionControlled($path, $is_absolute)) {
				my $msg = __x("template file '{path}' is not under version control",
				              path => $path);
				return $msg, Template::Constants::STATUS_ERROR;
			}

			if ($is_absolute) {
				my $srcdir = $qgoda->config->{srcdir};
				my $viewdir = File::Spec->join($srcdir, $qgoda->config->{paths}->{views});
				$path = File::Spec->abs2rel($path, $srcdir);
			} else {
				$path = File::Spec->join($qgoda->config->{paths}->{views}, $path);
			}

			my $deptracker = $qgoda->getDependencyTracker;
			$deptracker->addUsage($self->{__asset}->{relpath}, $path);
		}
	}

	return $self->SUPER::fetch($name);
}

1;

=head1 NAME

Qgoda::Processor::TT2 - Qgoda Processor For the Template Toolkit Version 2
