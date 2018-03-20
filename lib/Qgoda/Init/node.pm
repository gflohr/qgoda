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

package Qgoda::Init::node;

use strict;

use Locale::TextDomain qw('qgoda');
use File::Spec;

use Qgoda::Util qw(read_file write_file merge_data);

sub new {
    my ($class, $init) = @_;

    bless {
        __init => $init,
    }, $class;
}

sub run {
    my ($self, $config) = @_;

    my $q = Qgoda->new;
    my $logger = $q->logger;
    my $init = $self->{__init};

    my $npm = $init->getOption('npm');

    my @cmd = ($npm, 'init', '--yes');
    push @cmd, '--force' if $init->getOption('force');

    if (!$init->command(@cmd)) {
        $logger->error(__"Cannot setup asset processing.");
        return;
    }

    my @dev_deps = @{$config->{_node_dev_dependencies} || []};
    foreach my $dep (@dev_deps) {
        @cmd = ($npm, 'install', '--save-dev', $dep);
        $init->command(@cmd);
    }

    my @deps = keys @{$config->{_node_dependencies} || []};
    foreach my $dep (@deps) {
        @cmd = ($npm, 'install', '--save', $dep);
        $init->command(@cmd);
    }

    return $self if !$config->{_package};

    if ($config->{_package}) {
        $logger->info(__"updating 'package.json'");

        my $json = JSON->new;
        my $json_data = read_file 'package.json'
            or $logger->fatal(__x("Unable to read '{filename}': {error})",
                                  filename => 'package.json',
                                  error => $!));

        my $old = eval { $json->decode($json_data) };
        $logger->fatal($@) if $@;

        my $data = merge_data $old, $config->{_package};
        $json->pretty(1);
        $json_data = $json->encode($data);

        write_file 'package.json', $json_data
            or $logger->fatal(__x("Unable to write '{filename}': {error})",
                                  filename => 'package.json',
                                  error => $!));
    }

    return $self;
}

1;
