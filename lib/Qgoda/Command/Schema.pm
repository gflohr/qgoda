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

package Qgoda::Command::Schema;

use strict;

use YAML::XS;
use JSON;
use Data::Dumper;
use Storable qw(nfreeze);
use Locale::TextDomain qw(qgoda);

use Qgoda;
use Qgoda::Schema;

use base 'Qgoda::Command';

sub _getDefaults {
	format => 'json'
}

sub _getOptionSpecs {
	format => 'f|format=s'
}

sub _run {
	my ($self, $args, $global_options, %options) = @_;

	$global_options->{quiet} = 1;
	delete $global_options->{verbose};
	$global_options->{log_stderr} = 1;

	my $schema = Qgoda::Schema->config;
	if ('yaml' eq $options{format}) {
		print Dump($schema);
	} elsif ('json' eq $options{format}) {
		print JSON->new->canonical->encode($schema);
	} elsif ('perl' eq $options{format}) {
		print Dumper($schema);
	} elsif ('storable' eq $options{format}) {
		print nfreeze($schema);
	} else {
		die __x("Unsupported schema format '{format}'.\n",
		        format => $options{format});
	}
	return $self;
}

1;

=head1 NAME

qgoda schema - Print the Qgoda configuration schema

=head1 SYNOPSIS

qgoda [<global options>] schema [--format=FORMAT][--help]

Try 'qgoda --help' for a description of global options.

=head1 DESCRIPTION

Dump the JSON schema for the Qgoda configuration to the console (standard
output).

B<Important!> The Qgoda configuration schema is not constant.  It depends
on the directory from where you run the command, the set of plug-ins you
have installed, and the locale you have configured.  The purpose of the schema
is not to be a standard of any kind but to validate your configuration file
F<_config.yaml>.

=head1 OPTIONS

=over 4

=item -f, --format=FORMAT

Output the schema in format B<FORMAT>.  B<FORMAT> can be one of
L<json|https://www.json.org>, L<yaml|http://yaml.org>,
"perl" or "storable".

If the output format "perl" is chosen, the schema is dumped with
L<Data::Dumper>.  If the output format "storable" is chosen, the schema is
dumped with L<Storable>::nfreeze().  The latter is binary!

The default format is "json". If you plan to read and understand the output,
consider using "yaml" instead.

Alternatively, pipe the output of "qgoda schema" through L<jq(1)>:

	qgoda schema | jq .

Or into a readable file:

	qgoda schema | jq . >filename.json

Do not omit the dot ("."), it is important!

=item -h, --help

Show this help page and exit.

=back

=head1 BUGS AND CAVEATS

Since the schema is not constant, it should have a different $id attribute
for every possible constellation.

=head1 SEE ALSO

qgoda(1), L<https://json-schema.org/>, L<https://www.json.org/>,
L<http://yaml.org/>, L<Data::Dumper>, L<Storable>, jq(1), perl(1)

=head1 QGODA

Part of L<Qgoda|http://www.qgoda.net/>.
