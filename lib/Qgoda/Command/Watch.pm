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

package Qgoda::Command::Watch;

use strict;

#VERSION

use Qgoda;
use Qgoda::CLI;

use Locale::TextDomain qw(qgoda);

use base 'Qgoda::Command';

sub _getDefaults {}

sub _getOptionSpecs {
	drafts => 'D|drafts',
	future => 'F|future',
	dry_run => 'dry-run',
}

sub _run {
	my ($self, $args, $global_options, %options) = @_;

	Qgoda->new($global_options)->watch(%options);

	return $self;
}

1;

=head1 NAME

qgoda watch - Build a qgoda site and watch for changes

=head1 SYNOPSIS

qgoda watch [<global options>] [--drafts][--future][--dry-run][--help]

Try 'qgoda --help' for a description of global options.

=head1 DESCRIPTION

Does exactly the same as `qgoda build` but does not terminate (hit CTRL-C
or close the terminal window instead).

If the initial build was successful, the program monitors the file system
and starts a new build, whenever an input file was modified, deleted or
created.  Subsequent build failures are not fatal.

Whenever a build was finished, successful or not, the number of seconds elapsed
since the epoch are written into the file F<_timestamp>.  This can be used
as a trigger to reload pages in the browser, restart a service, or similar.

=head1 OPTIONS

=over 4

=item -D, --drafts

Process draft documents (documents with the draft property set)

=item -F, --future

Process documents with a date (date property) in the future

=item --dry-run

Just print what would be done but do not write any files.

=item -h, --help

Show this help page and exit.

=back

=head1 SEE ALSO

L<Qgoda::Command::Build>, qgoda(1)

=head1 QGODA

Part of L<Qgoda|http://www.qgoda.net/>.
