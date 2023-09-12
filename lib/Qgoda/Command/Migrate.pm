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

package Qgoda::Command::Migrate;

use strict;

#VERSION

use Qgoda;
use Qgoda::CLI;
use Qgoda::Util qw(perl_class class2module);

use Locale::TextDomain qw(qgoda);
use List::Util qw(pairs);

use base 'Qgoda::Command';

use constant TRIGGER_FILES => [
	'_config.yml' => 'Jekyll',
	'_config.yaml' => 'Jekyll',
];

sub _getDefaults {}

sub _getOptionSpecs {
	from => 'f|from=s',
	output_directory => 'o|output-directory=s',
	remove => 'r|remove|force',
	in_place => 'i|in-place',
	settings => 's|settings=s%',
}

sub _run {
	my ($self, $args, $global_options, %options) = @_;

	$options{from} ||= $self->__detectSystem;

	if (!$options{from}) {
		Qgoda::CLI->commandUsageError(
			'migrate',
			__"cannot auto-detect system, please use option '--from'",
			'migrate [OPTIONS]');
	}

	if ($options{in_place}) {
		$options{output_directory} = '.';
		delete $options{remove};
	} elsif (!exists $options{output_directory}
	         || !length $options{output_directory}) {
		Qgoda::CLI->commandUsageError(
			'migrate',
			__"either option '--output-directory' or '--in-place' is required",
			'migrate [OPTIONS]');
	}

	my $qgoda = Qgoda->new($global_options, { no_config => 1 });
	my $logger = $qgoda->logger('migrate');

	my $system = $options{from};
	if (!perl_class $system) {
		Qgoda::CLI->commandUsageError(
			'migrate',
			__x("the system '{system}' is not supported", system => $system),
			'migrate [OPTIONS]',
		);
	}

	my $canonical_system = join '::', map { ucfirst lc $_ } split /::/, $system;
	my $class= "Qgoda::Migrator::$canonical_system";
	my $module = class2module $class;
	eval { require $module };
	if ($@) {
		Qgoda::CLI->commandUsageError(
			'migrate',
			__x("the system '{system}' is not supported: {error}",
			    system => $system, error => $@),
			'migrate [OPTIONS]',
		);
	}

	my $migrator;
	eval { $migrator = $class->new($args, $global_options, %options) };
	if ($@) {
		$canonical_system = lc $canonical_system;
		$logger->prefix("migrate][$canonical_system");
		$logger->fatal($@);
	}

	eval { $migrator->run };
	if ($@) {
		$logger = $migrator->logger;
		$logger->fatal($@);
	}

	return $self;
}

sub __detectSystem {
	my ($self) = @_;

	foreach my $pair (@{[TRIGGER_FILES]}) {
		my ($file, $system) = (@$pair);
		return $system if -e $file;
	}

	return;
}

1;

=head1 NAME

qgoda migrate - Migrate a static website to Qgoda

=head1 SYNOPSIS

qgoda migrate [<global options>] [--from=Jekyll] [--in-place]

Try 'qgoda --help' for a description of global options.

=head1 DESCRIPTION

Migrates a site to Qgoda to the extent possible.  The migration will try to
mention possible errors or limitations on the console.

=head1 OPTIONS

=over 4

=item -f, --from=SYSTEM

Use the migrator for B<SYSTEM>.  The default is to autodetect the system.

Currently supported systems are:

=over 8

=item Jekyll, see L<https://jekyllrb.com/>.

=back

=item -o, --output-directory=DIRECTORY

Store the migrated site in B<DIRECTORY>.  The directory must be empty if it
exists.

=item -r, --remove, --force

Remove the output directory before starting the migration.  This option only
makes sense with option C<--output-directory>.

=item -i, --in-place

Modify the system in place.

=item -s, --settings=KEY=VALUE

Set migration setting B<KEY> to B<VALUE>.

=back

=head1 SEE ALSO

qgoda(1)

=head1 QGODA

Part of L<Qgoda|http://www.qgoda.net/>.

=cut
