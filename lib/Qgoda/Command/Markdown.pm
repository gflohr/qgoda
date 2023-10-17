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

package Qgoda::Command::Markdown;

use strict;

#VERSION

use Locale::TextDomain qw(qgoda);

use Qgoda;
use Qgoda::CLI;
use Qgoda::Util qw(read_file);

use base 'Qgoda::Command';

sub _run {
	my ($self, $args, $global_options, %options) = @_;

	$args = ['-'] if !@$args;
	my $count = 0;
	map { ++$count if '-' eq $_ } @$args;
	Qgoda::CLI->commandUsageError(markdown =>
								  __"can only read once from standard input")
		if $count > 1;

	$global_options->{quiet} = 1;
	delete $global_options->{verbose};
	$global_options->{log_stderr} = 1;

	my $q = Qgoda->new($global_options);
	my ($processor) = $q->_getProcessors('Markdown');
	if (!$processor) {
		die __x("error instantiating processor '{processor}'.\n",
				processor => 'Markdown');
	}

	foreach my $arg (@$args) {
		$self->__processFile($processor, $arg);
	}

	return $self;
}

sub __processFile {
	my ($self, $processor, $filename) = @_;

	my $markdown;
	if ('-' eq $filename) {
		$filename = __("[standard input]");
		$markdown = join '', <STDIN>;
	} else {
		$markdown = read_file $filename;
		die __x("unable to open '{filename}' for reading: {error}!\n",
				filename => $filename, error => $!)
			if !defined $markdown;
	}

	print $processor->process($markdown);

	return $self;
}

1;

=head1 NAME

qgoda markdown - Run text through a Markdown processor

=head1 SYNOPSIS

qgoda markdown [<global options>]
			   [--processor=<Markdown processor>] [<file>...]

Try 'qgoda --help' for a description of global options.

=head1 DESCRIPTION

Runs the specified files through the Markdown processor and prints the
result to standard output.  If no files are specified, or '-' is specified,
standard input is read.

This command does not aim to compete with other Markdown command-line tools.
Its purpose is to allow testing Markdown snippets with the Markdown processors
in use within Qgoda.

=head1 OPTIONS

=over 4

=item -h --help

Show this help page and exit.

=back

=head1 SEE ALSO

L<Text::Markdown::Discount>(3pm), qgoda(1), perl(1)

=head1 QGODA

Part of L<Qgoda|http://www.qgoda.net/>.
