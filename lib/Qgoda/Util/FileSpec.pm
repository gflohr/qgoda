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

package Qgoda::Util::FileSpec;

use strict;

#VERSION

use File::Spec;

use base 'Exporter';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(absolute_path abs2rel catdir catfile updir curdir rel2abs
                splitpath catpath filename_is_absolute no_upwards
                canonical_path splitdir);

# Wrapper around File::Spec that forces the slash as a path separator.

sub __fixup($) {
	my ($path) = @_;

	$path =~ s{\\}{/}g;
	$path =~ s{/$}{} unless '/' eq $path;

	return $path;
}

# Not defined by File::Spec but protect against using it for absolute paths
# which does not work with MS-DOS.
sub absolute_path {
	my ($path) = @_;

	if (!defined $path || !length $path) {
		return Cwd::abs_path();
	}

	if (!File::Spec->file_name_is_absolute($path)) {
		$path = File::Spec->rel2abs($path);
	}

	__fixup $path;
}

sub abs2rel {
	my ($path, $base) = @_;

	$path = File::Spec->abs2rel($path, $base);

	__fixup $path;
}

sub canonical_path {
	my ($path) = @_;

	$path = File::Spec->canonpath($path);

	__fixup $path;
}

sub catfile {
	my (@directories) = @_;

	my $path = File::Spec->catfile(@directories);

	__fixup $path;
}

sub catdir {
	my (@directories) = @_;

	my $path = File::Spec->catdir(@directories);

	__fixup $path;
}

sub catpath {
	my ($volume, $directory, $file) = @_;

	my $path = File::Spec->catpath($volume, $directory, $file);

	__fixup $path;
}

sub filename_is_absolute {
	my ($path) = @_;

	return File::Spec->file_name_is_absolute($path);
}

sub no_upwards {
	return File::Spec->no_upwards(@_);
}

sub rel2abs {
	my ($path, $base) = @_;

	$path = File::Spec->rel2abs($path, $base);

	__fixup $path;
}

sub splitdir {
	my ($directory) = @_;

	return File::Spec->splitdir($directory);
}

sub splitpath {
	File::Spec->splitpath(@_);
}

sub curdir {
	File::Spec->curdir;
}

sub updir {
	File::Spec->updir;
}

1;
