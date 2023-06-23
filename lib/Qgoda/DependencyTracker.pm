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

package Qgoda::DependencyTracker;

use strict;

sub new {
	my ($class) = @_;

	bless {
		__used_by => {},
		__descendants => {},
		__outfiles => {},
	}, $class;
}

sub addArtefact {
	my ($self, $parent, $path) = @_;

	$self->{__descendants}->{$parent->{relpath}}->{$path} = 1;
	$self->{__outfiles}->{$path} = 1;

	return $self;
}

sub addUsage {
	my ($self, $user_path, $dep_path) = @_;

	$self->{__used_by}->{$dep_path}->{$user_path} = 1;

	return $self;
}

sub getUsages {
	shift->{__used_by};
}

sub compute {
	my ($self, $changeset) = @_;

	$self->{__dirty} = {};
	$self->{__outfiles} = {};
	my $qgoda = Qgoda->new;
	my $site = $qgoda->getSite;
	$site->reset(1);
	foreach my $relpath (@$changeset) {
		$self->__addChange($relpath, $site);
		return $self if !$self->__isActive;
	}

	return $self;
}

sub dirty {
	my ($self) = @_;

	return [keys %{$self->{__dirty}}] if $self->{__dirty};

	return;
}

sub outfiles {
	my ($self) = @_;

	return [keys %{$self->{__outfiles}}];
}

sub __isView {
	my ($self, $path) = @_;

	my $viewdir = Qgoda->new->config->{paths}->{views};
	my $vlength = length $viewdir;
	if ($viewdir eq substr $path, 0, $vlength) {
			return 1;
	} else {
			return;
	}
}

sub __reset {
	my ($self, $site) = @_;

	delete $self->{__dirty};
	$self->{__outfiles} = {};
	$site->reset;

	return $self;
}

sub __isActive {
	shift->{__dirty};
}

sub __addChange {
	my ($self, $relpath, $site) = @_;

	my $dirty = $self->{__dirty};
	my $outfiles = $self->{__outfiles};
	my $relpath_is_view = $self->__isView($relpath);
	my $deleted = !-e $relpath;
	if (!$relpath_is_view && !$deleted) {
		$dirty->{$relpath} = 1;
	}

	if ($deleted && !$relpath_is_view) {
		$site->removeAssetByRelpath($relpath);
	}

	if (exists $self->{__used_by}->{$relpath}) {
		my $users = delete $self->{__used_by}->{$relpath};
		foreach my $user (keys %$users) {
			my $is_view = $self->__isView($user);
			if (!exists $dirty->{$user}) {
				$dirty->{$user} = 1 if -e $user && !$is_view;
				$self->__addChange($user, $site);
				return $self if !$self->__isActive;
			}
		}
	} elsif (!$relpath_is_view && !$deleted &&
	         !$site->getAssetByRelpath($relpath)) {
		return $self->__reset($site);
	}

	if (exists $self->{__descendants}->{$relpath}) {
		my $descendants = delete $self->{__descendants}->{$relpath};
		foreach my $descendant (keys %$descendants) {
			$self->{__outfiles}->{$descendant} = 1;
			$site->removeArtefact($descendant);
		}
	}

	return $self;
}

1;
