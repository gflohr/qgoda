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

package Qgoda::Command::Xgettext;

use strict;

use Qgoda;
use Qgoda::Locale::XGettext;

use base 'Qgoda::Command';

sub run {
    my ($self, $args, $global_options) = @_;

    $global_options->{quiet} = 1;
    delete $global_options->{verbose};
    $global_options->{log_stderr} = 1;

    Qgoda::Locale::XGettext->newFromArgv($args)->run->output;

    return $self;
}

sub _run {
    my ($self, $args, $global_options, %options) = @_;


    return $self;
}

sub _displayHelp {
    my ($self) = @_;

    Qgoda::Locale::XGettext->newFromArgv(['--help']);
}

1;
