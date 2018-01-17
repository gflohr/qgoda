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
    output_directory => '_migrated'
}

sub _getOptionSpecs {
    from_system => 'f|from-sytem',
    output_directory => 'o|output-directory',
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

Try 'qgoda --help' for a description of global options.

=head1 DESCRIPTION

Builds a Qgoda powered site.  In brief it does the following:

It reads its configuration from the file F<_config.yaml> in the current
working directory.

It collects all files in the current directory but ignores all files and
directories with names starting with an underscore ('_').

If a file contains front matter, that front matter is taken as meta
information about that file.  Front-matter is in L<YAML|http://yaml.org>
format:

    ---
    title: My first blog post
    type: post
    ---
    Text with *markup* or [% TemplateToolkit %] code follows.

If the file does not contain front matter, default values are applied
and no processing takes place.

The resulting output is then copied to the output directory F<_site>.

After the build was finished, the number of seconds elapsed since the epoch
is written into the file F<_timestamp>.

If you want to continuously recreate the site, whenever an input file
was modified, created or deleted, try the command F<qgoda watch> instead!

See L<http://www.qgoda.net/> for detailed information!

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
