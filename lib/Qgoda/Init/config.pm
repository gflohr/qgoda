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

package Qgoda::Init::config;

use strict;

#VERSION

use Locale::TextDomain qw('qgoda');
use YAML;

use Qgoda::Util qw(merge_data read_file write_file);

sub new {
	my ($class, $init) = @_;

	bless {
		__init => $init,
	}, $class;
}

sub run {
	my ($self, $new) = @_;

	my $q = Qgoda->new;
	my $logger = $q->logger;

	# Make a shallow copy of the new configuration ...
	$new = {%$new};

	# ... and delete all keys that are not meant to be kept.
	foreach my $key (keys %$new) {
		delete $new->{$key} if $key =~ /^_/;
	}

	my $filename;
	if (-e '_config.yaml') {
		$filename = '_config.yaml';
	} elsif (-e '_config.yml') {
		$filename = '_config.yml';
	}

	if ($filename && !$self->{__init}->getOption('force')) {
		$logger->warning(__x("not overwriting '{file}' without '--force'",
							 file => $filename));
		$logger->warning(__"This can lead to malfunctions.");
		$logger->warning(__"Please merge '_config.new.yaml' manually!");
		my $yaml = YAML::Dump($new);
		write_file '_config.new.yaml', $yaml
			or $logger->fatal(__x("cannot write '{filename}': {error}",
								  filename => '_config.new.yaml',
								  error => $!));
	}

	# Reread the current configuration.  This allows us to preserve the order
	# of the keys.  Note that the XS version does not support that option.
	my $old = {};
	if ($filename) {
		my $yaml = read_file $filename
			or $logger->fatal(__x("cannot read '{filename}': {error}",
								   filename => $filename,
								   error => $!));

		local $YAML::Preserve = 1;
		$old = YAML::Load($yaml);
	}
	my $data = merge_data $old, $new;

	$filename ||= '_config.yaml';

	my $yaml = YAML::Dump($data);
	write_file $filename, $yaml
		or $logger->fatal(__x("cannot write '{filename}': {error}",
							   filename => $filename,
							   error => $!));

	# Reload the new configuration.
	$logger->info(__"force reload of configuration");
	$q->_reload;

	return $self;
}

1;
