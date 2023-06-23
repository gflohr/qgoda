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

package Qgoda::Locale::XGettext;

use strict;

use Locale::TextDomain qw(qgoda);
use Cwd qw(getcwd realpath);
use Scalar::Util qw(reftype);
use File::Spec;
use Locale::XGettext 0.7;

use Qgoda;
use Qgoda::Util qw(read_file flatten2hash);
use Qgoda::Util::Translate qw(get_mains);
use Qgoda::CLI;
use Qgoda::Splitter;

use base qw(Locale::XGettext);

sub readFile {
	my ($self, $filename) = @_;

	$self->{__qgoda_files} ||= [];
	push @{$self->{__qgoda_files}}, $filename;

	return $self;
}

sub extractFromNonFiles {
	my ($self) = @_;

	my $podir = getcwd;
	my $srcdir = File::Spec->rel2abs($self->option('srcdir'));

	if (!chdir $srcdir) {
		die __x("error changing working directory to '{dir}': {error}\n",
				dir => $srcdir, error => $!);
	}

	my $qgoda = Qgoda->new({
		quiet => 1,
		verbose => 0,
		log_stderr => 1,
	});

	my %mains = get_mains;
	my %mains_paths;
	foreach my $relpath (keys %mains) {
		my $abs = realpath(File::Spec->rel2abs($relpath, $srcdir));
		$mains_paths{$abs} = $relpath;
	}

	foreach my $filename (@{$self->{__qgoda_files}}) {
		my $abs = realpath(File::Spec->rel2abs($filename, $podir));
		if (exists $mains_paths{$abs}) {
			my $relpath = $mains_paths{$abs};
			my $translations = $mains{$relpath};
			$self->__extractFromMain($filename, $relpath, $translations);
		}
	}

	if (!chdir $podir) {
		die __x("error changing working directory to '{dir}': {error}\n",
				dir => $podir, error => $!);
	}

	return $self;
}

sub __extractFromMain {
	my ($self, $filename, $main, $translations) = @_;

	my %translate;
	my $site = Qgoda->new->getSite;
	foreach my $relpath (%$translations) {
		my $asset = $translations->{$relpath};
		my $translate = $asset->{translate};
		next if !defined $translate;
		if (ref $translate && 'ARRAY' eq reftype $translate) {
			map { $translate{$_} = 1 } @$translate;
		} else {
			$translate{$translate} = 1;
		}
	}

	my $main_asset = $site->getAssetByRelpath($main);
	if (!$main_asset) {
		my $path = File::Spec->rel2abs($main, $self->option('srcdir'));
		$main_asset = Qgoda::Asset->new($path, $main);
	}
	my $splitter = Qgoda::Splitter->new($main_asset->getPath);

	my $meta = $splitter->meta;
	foreach my $key (sort {$splitter->metaLineNumber($a)
						   <=> $splitter->metaLineNumber($b)
					 } keys %translate) {
		next if !exists $main_asset->{$key};
		my $slice = { $key => $main_asset->{$key}};
		my $flat = flatten2hash $slice;
		foreach my $variable (keys %$flat) {
			my $msgid = $flat->{$variable};
			if ($variable =~ /(.+)\.[0-9]+$/) {
				my $root = $1;
				if (ref $slice->{$root} && 'ARRAY' eq reftype $slice->{$root}) {
					$variable = $root;
				}
			}
			$self->addEntry(
				msgid => $msgid,
				msgctxt => $variable,
				reference => $filename . ':' . $splitter->metaLineNumber($key),
			);
		}
	}

	foreach my $entry ($splitter->entries) {
		$self->addEntry(
			msgid => $entry->{text},
			reference => $filename . ':' . $entry->{lineno},
			msgctxt => $entry->{msgctxt},
			comment => $entry->{comment},
		);
	}

	return $self;
}

sub programName {
	$0 . ' xgettext';
}

sub canFlags { return }
sub canKeywords { return }
sub canExtractAll { return }

sub languageSpecificOptions {
	return [
		[
			'--srcdir=s',
			'srcdir',
			'	--srcdir=SRCDIR',
			__"the Qgoda top-level source directory (defaults to '..')",
		]
	];
}

sub versionInformation {
	Qgoda::CLI->displayVersion;
}

1;
