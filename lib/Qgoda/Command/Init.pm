#! /bin/false

# Copyright (C) 2016-2018 Guido Flohr <guido.flohr@cantanea.com>,
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

package Qgoda::Command::Init;

use strict;

use Qgoda;

use base 'Qgoda::Command';

sub _getDefaults { npm => 'npm', skip => [] }

sub _getOptionSpecs { 
    force => 'f|force+', 
    npm => 'n|npm=s', 
    skip => 's|skip=s@'
}

sub _run {
    my ($self, $args, $global_options, %options) = @_;

    Qgoda->new($global_options)->init($args, %options);

    return $self;
}

1;

=head1 NAME

qgoda init - Initialize a Qgoda site with a theme

=head1 SYNOPSIS

qgoda init [<global options>] [-f|--force] [-n|--npm=PROGRAM] 
           [-s|--skip=TASK] [<repository>]

Try 'qgoda --help' for a description of global options.

=head1 DESCRIPTION

Initializes or updates a new Qgoda site with a pre-defined theme.

If B<repository> is omitted, L<http://github.com/gflohr/qgoda-default> is
used.

If the current directory already contains a qgoda site, only new files
are copied into it, unless the option '--force' was given.

The same applies to the update of the configuration file F<_config.yaml>.
If it exists, and the option '--force' was given, the current configuration
is merged with the default remote configuration from the theme.

The command neither implies "qgoda build" nor "qgoda watch".  If the theme
configures an external helper program such as "yarn", "npm", "make" and so on,
a warning is printed.

=head1 FORMAT OF REPOSITORY STRINGS

You can specify the repository in one of the following format:

=over 4

=item git://github.com/gflohr/qgoda-site

=item git+ssh://example.com/foo/bar

=item git+http://github.com/gflohr/qgoda-site

=item git+https://github.com/gflohr/qgoda-site

=item git+file:///var/git/qgoda/fancy.git

All of these strings are passed as is to "git clone".

=item gflohr/qgoda-default

A shortcut for "git://github.com/gflohr/qgoda-default".

=item http://git.example.com/foo/bar.tar.gz

If a URI points to a archive file format, the archive is downloaded and
extracted to the current directory.

=item file:///path/to/directory

The contents of the directory is copied.

=back

=head1 OPTIONS

=over 4

=item -f, --force

Update (and overwrite) files and merge configurations.  You can give
the option twice in order to also overwrite files which are considered
"precious" by the theme author.  Most themes will only consider markdown
documents as precious.

=item -n, --npm=PROGRAM

Use B<PROGRAM> instead of F<npm> for initializing Node.JS dependencies.

You currently can B<not> use yarn instead of npm!

=item -s, --skip=TASK

Skip task B<TASK>.  Current tasks are:

=over 8

=item copy

Copy files from repository.

=item config

Update F<_config.yaml>.  Note that the configuration file is only updated,
when the option "--force" was specified on the command-line.

=item node

Do not update the project with the Node Package Manager NPM.

=back

You can specify the option multiple times if you want to skip multiple tasks.

=item -h, --help

Show this help page and exit.

=back

=head1 SEE ALSO

qgoda(1), git(1)

=head1 QGODA

Part of L<Qgoda|http://www.qgoda.net/>.
