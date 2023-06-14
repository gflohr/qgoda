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

package Qgoda::Command::Javascript;

use strict;

use Locale::TextDomain qw(qgoda);
use JSON;
use Storable;
use YAML::XS;

use Qgoda;
use Qgoda::CLI;
use Qgoda::JavaScript::Environment;
use Qgoda::Util qw(empty read_file);

use base 'Qgoda::Command';

sub _getDefaults {
	global => [],
	input_format => 'json'
}

sub _getOptionSpecs {
	input => 'i|input=s',
	input_data => 'input-data=s',
	input_format => 'input-format=s',
	global => 'global=s',
	no_output => 'no-output',
	no_console => 'no-console'
}

sub _run {
	my ($self, $args, $global_options, %options) = @_;

	my $q = Qgoda->new({quiet => 1, log_stderr => 1});

	if (!empty $options{input} && !empty $options{input_data}) {
		die __"The options '--input' and '--input-format' are mutually "
			. "exlusive!\n";
	}

	my $lc_format = lc $options{input_format};
	die __x("Unsupported input format '{format}'.\n",
			format => $options{input_format})
		if ($lc_format ne 'json' && $lc_format ne 'yaml'
			&& $lc_format ne 'perl' && $lc_format ne 'storable');

	my $code = '';
	if ($args && @$args) {
		foreach my $arg (@$args) {
			my $content = read_file $arg;
			die __x("error reading '{filename}': {error}!\n",
					filename => $arg, error => $!)
				if !defined $content;
			$code .= $content;
		}
	} else {
		$code = join '', <STDIN>;
	}

	my $input_data;
	my $input_filename = __"[option --input-data]";
	if (!empty $options{input_data}) {
		$input_data = $options{input_data};
	} elsif (!empty $options{input}) {
		$input_filename = $options{input};
		my $content = read_file $input_filename;
		die __x("error reading '{filename}': {error}!\n",
				filename => $input_filename, error => $!)
			if !defined $content;
		$input_data = $content;
	}

	if (defined $input_data) {
		eval {
			if ('json' eq $lc_format) {
				$input_data = JSON->new->allow_nonref
								  ->allow_blessed->convert_blessed->utf8
								  ->decode($input_data);
			} elsif ('yaml' eq $lc_format) {
				$input_data = YAML::XS::Lod($input_data);
			} elsif ('perl' eq $lc_format) {
				$input_data = eval $input_data;
				die $@ if $@;
			} elsif ('storable' eq $lc_format) {
				$input_data = Storable::thaw($input_data);
			}
		};
		if ($@) {
			die __x("error reading input data from '{filename}': {error}!\n",
					filename => $input_filename, error => $@);
		}
	}

	my @global = (@{$options{global}}, $q->nodeModules);
	my $js = Qgoda::JavaScript::Environment->new(
		no_output => $options{no_output},
		no_console => $options{no_console},
		global => \@global
	);

	$js->exchange(input => $input_data) if defined $input_data;

	$js->run($code);

	return $self;
}

1;

=head1 NAME

qgoda javascript - Execute JavaScript code inside Qgoda

=head1 SYNOPSIS

	qgoda javascript [<global options>] [-i|--input=FILENAME]
					 [-g|--global=MODULE_DIR1] [-g|--global=MODULE_DIR2]
					 [--input-data=DATA]
					 [--input-format=JSON|YAML|Perl|Storable]
					 [--no-stdout] [--no-stderr]
					 [FILENAME...]

Try 'qgoda --help' for a description of global options.

=head1 DESCRIPTION

Executes JavaScript code inside Qgoda, using the embedded JavaScript
engine L<Duktape|https://duktape.org/>. This is not meant as a serious
JavaScript interpreter or command-line frontend to Duktape but rather
a debugging aid for Qgoda.

You have to pass a filename containing JavaScript code as an argument
or prove the code on standard input.

Note that Duktape is B<not> NodeJS! Not all constructs accepted by NodeJS
are accepted by Duktape!

Qgoda, however, implements a module resolver so that you can use constructs
like:

	const _ = require('lodash');

The module is resolved in the same way that NodeJS would resolve it.
See the option I<--global> below for more information.

=head1 OPTIONS

=over 4

=item I<-i, --input=FILENAME>

Data stored in B<FILENAME> is assigned to the global JavaScript variable
C<__perl__.input>.  This is the common convention for JavaScript code in
Qgoda for injecting input variables to JavaScript code.

=item I<--input-format=FORMAT>

The input format used for input data.  Must be one of:

=over 4

=item I<JSON>

See L<https://www.json.org/>.

=item I<YAML>

See L<http://yaml.org>.

=item I<Perl>

The input will be evaluated as Perl code.  You can produce such input
manually or with L<Data::Dumper> or L<Data::Dump>.

=item I<Storable>

Data that can be deserialized with L<Storable>::thaw().

=back

The default is "JSON".  Case does not matter.

=item I<--input-data=DATA>

Like I<--input> but the data is not read from a file but from the string
B<DATA>.  The data format is determined by I<--input-format>.

=item I<-g|--global=DIRECTORY>

Prepend B<DIRECTORY> to the list of global directories to search for
JavaScript modules.  The default is the Qgoda package directory, that
is the same path where F<Qgoda.pm> is installed but without the trailing
F<.pm>.

The B<DIRECTORY> should be specified I<without> the trailing F<node_modules>.

=item I<--no-console>

Do not use Qgoda's console polyfill but that of Duktape itself.  Note that
the Duktape console polyfill only supports C<console.log()>!

=item I<--no-output>

Save standard output and standard error instead of printing it to the console.
The output is available later by calling
C<Qgoda->new->jsout> resp. C<Qgoda->new->jserr>.  This is useful for unit
testing only.

=item I<-h, --help>

Show this help page and exit.

=back

=head1 SEE ALSO

qgoda(1), L<Qgoda::JavaScript::Environment>, L<JavaScript::Duktape::XS>,
L<Data::Dumper>, L<Data::Dump>, L<Storable>,
L<https://www.json.org/>, L<http://yaml.org>, L<https://duktape.org/>,
L<https://nodejs.org>

=head1 QGODA

Part of L<Qgoda|http://www.qgoda.net/>.

=cut
