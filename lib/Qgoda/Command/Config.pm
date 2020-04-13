#! /bin/false

# Copyright (C) 2016-2020 Guido Flohr <guido.flohr@cantanea.com>,
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

package Qgoda::Command::Config;

use strict;

use Qgoda;

use base 'Qgoda::Command';

sub _getDefaults {}

sub _getOptionSpecs {}

sub _run {
    my ($self, $args, $global_options, %options) = @_;

    $global_options->{quiet} = 1;
    delete $global_options->{verbose};
    $global_options->{log_stderr} = 1;

    Qgoda->new($global_options)->printConfig;

    return $self;
}

1;

=head1 NAME

qgoda config - Dump the Qgoda configuration

=head1 SYNOPSIS

qgoda [<global options>] config [--help]

Try 'qgoda --help' for a description of global options.

=head1 DESCRIPTION

Dump the Qgoda configuration to the console (standard output).  The
configuration is the merged super set of the Qgoda default configuration,
the configuration read from F<_config.yaml> (resp. F<_config.yml> or]
F<_config.json>) and  F<_localconfig.yaml> (resp. F<_localconfig.yml>
or F<_localconfig.json>).

If none of these files exist, the Qgoda default configuration is printed out.

The output format is YAML.

=head1 OPTIONS

=over 4

=item -h, --help

Show this help page and exit.

=back

=head1 SEE ALSO

qgoda(1), L<http://yaml.org/>, perl(1)

=head1 QGODA

Part of L<Qgoda|http://www.qgoda.net/>.
