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

package Qgoda::Command::Migrate;

use strict;

use Qgoda;
use Qgoda::CLI;

use Locale::TextDomain qw(qgoda);

use base 'Qgoda::Command';

sub _getDefaults {
    from_system => 'Jekyll',
}

sub _getOptionSpecs {
    from_system => 'f|from-sytem=s',
    output_directory => 'o|output-directory=s',
}

sub _run {
    my ($self, $args, $global_options, %options) = @_;

    Qgoda->new($global_options)->migrate(%options);

    return $self;
}

1;

=head1 NAME

qgoda migrate - Migrate a site from another static site generator

=head1 SYNOPSIS

qgoda migrate [<global options>] [-n|--no-change|--dry-run]
              [--output-directory=DIRECTORY]

Try 'qgoda --help' for a description of global options.

=head1 DESCRIPTION

Migrates a site that was created with another software.  The only supported
software at the moment is L<Jekyll|https://jekyllrb.com/>.

=head1 OPTIONS

=over 4

=item -o, --output-directory=DIRECTORY

Where to save the migrated site.

=item -n, --dry-run, --no-change

Just print what would be done but do not write any files.

=item -h, --help

Show this help page and exit.

=back

=head1 SEE ALSO

qgoda(1)

=head1 QGODA

Part of L<Qgoda|http://www.qgoda.net/>.

=cut
