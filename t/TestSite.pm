#! /bin/false # -*- perl -*-

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

package TestSite;

use strict;

use File::Path;
use File::Find;
use File::Globstar::ListMatch;
use YAML::XS;
use Encode;

use Qgoda;
use Qgoda::Util qw(empty write_file);
use Qgoda::Util::FileSpec qw(
	absolute_path abs2rel catdir catfile catpath curdir rel2abs splitpath
	updir filename_is_absolute
);

my $repodir;
BEGIN {
	# Make @INC absolute.
	foreach my $path (@INC) {
		if (!filename_is_absolute $path) {
			$path = absolute_path $path;
		}
	}
    my ($volume, $directory) = splitpath __FILE__;
	$repodir = catpath $volume, $directory, updir;
	$repodir = absolute_path(rel2abs($repodir));
}

sub new {
	my ($class, %options) = @_;

	if (empty $options{name}) {
		require Carp;
		Carp::croak("The option 'name' is mandatory");
	}

	my $self = bless \%options, $class;
	$self->setup;

	return $self;
}

sub setup {
	my ($self) = @_;

	my ($volume, $directory) = splitpath __FILE__;

	chdir $repodir or die "cannot chdir to '$repodir': $!\n";

	my $rootdir = catfile($repodir, 't', $self->{name});
	$self->{rootdir} = $rootdir;
    $self->tearDown if -e $self->{rootdir};
	mkdir $rootdir;
	chdir $rootdir or die "cannot chdir to '$rootdir': $!\n";

	$self->__setupConfig;
	$self->__setupFiles;
	$self->__setupAssets;

	unless ($self->{verbose}) {
		eval {
			Qgoda->reset;
			Qgoda->new({quiet => 1, log_stderr => 1});
		};
		$self->{__exception} = $@;
	}

	return $self;
}

sub exception { shift->{__exception} }

sub __setupConfig {
	my ($self) = @_;

    my $yaml;

	if (empty $self->{config}) {
		unlink '_qgoda.yaml';
		return $self;
	} elsif (ref $self->{config}) {
        $yaml = YAML::XS::Dump($self->{config});
    } else {
        $yaml = $self->{config};
    }

	write_file '_qgoda.yaml', $yaml or die;

	return $self;
}

sub __setupAssets {
	my ($self) = @_;

	foreach my $relpath (keys %{$self->{assets} || {}}) {
		my $asset = $self->{assets}->{$relpath};
		my $content = delete $asset->{content};
		$content = '' if !defined $content;
		if ($asset->{raw}) {
			write_file $relpath, $content
				or die "cannot write '$relpath': $!";
		} else {
			my $data = keys %$asset ? YAML::XS::Dump($asset) : "---\n";
			$data .= "---\n$content";
			Encode::_utf8_on($data);
			write_file $relpath, $data
				or die "cannot write '$relpath': $!";
		}
	}

	return $self;
}

sub __setupFiles {
	my ($self) = @_;

	foreach my $relpath (keys %{$self->{files} || {}}) {
		my $content = $self->{files}->{$relpath};
		write_file $relpath, $content
			or die "cannot write '$relpath': $!";
	}

	return $self;
}

sub tearDown {
	my ($self) = @_;

	chdir $repodir or die "cannot chdir to '$repodir': $!\n";

	my $matcher = File::Globstar::ListMatch->new($self->{precious} || []);
	File::Find::finddepth({
		wanted => sub {
			my $rel = abs2rel($File::Find::name, $self->{rootdir});

			return if '.' eq $rel;
			return if $matcher->match($rel);

			if (-d $File::Find::name) {
				rmdir $File::Find::name;
			} else {
				unlink $File::Find::name;
			}
		},
	}, $self->{rootdir});
	rmdir $self->{rootdir};

	return $self;
}

sub findArtefacts {
	my ($self, $relpath) = @_;

	my $path = catdir(curdir, '_site');
	$path = catdir($path, $relpath) if !empty $relpath;

	my @artefacts;
	File::Find::find({
		wanted => sub { push @artefacts, $File::Find::name if !-d $_ }
	}, $path);

	return wantarray ? sort @artefacts : scalar @artefacts;
}

1;
