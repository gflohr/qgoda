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

package Qgoda::Command;

use strict;

use File::Spec;
use Getopt::Long 2.36 qw(GetOptionsFromArray);

use Qgoda::CLI;
use Qgoda::Util qw(class2module);

sub new {
    my ($class) = @_;

    my $self = '';
    bless \$self, $class;
}

sub run {
    my ($self, $args, $global_options) = @_;

    $args ||= [];
    my %options = $self->parseOptions($args);

    return $self->_run($args, $global_options, %options);
}

sub parseOptions {
    my ($self, $args) = @_;

    my %options = $self->_getDefaults;
    my %specs = $self->_getOptionSpecs;
    $specs{help} = 'h|help';

    my %optspec;
    foreach my $key (keys %specs) {
        $optspec{$specs{$key}} = 
                ref $options{$key} ? $options{$key} : \$options{$key};
    }

    Getopt::Long::Configure('bundling');
    {
        local $SIG{__WARN__} = sub {
            $SIG{__WARN__} = 'DEFAULT';
            $self->__usageError(shift);
        };

        GetOptionsFromArray($args, %optspec);
    }

    # Exits.
    $self->_displayHelp if $options{help};

    return %options;
}

sub _getDefaults {}
sub _getOptionSpecs {};

sub __usageError {
    my ($self, @msg) = @_;

    my $class = ref $self;
    $class =~ s/^Qgoda::Command:://;
    my $cmd = join '-', map { lcfirst $_ } split /::/, $class;

    return Qgoda::CLI->commandUsageError($cmd, @msg);
}

sub _displayHelp {
    my ($self) = @_;

    my $module = class2module ref $self;

    my $path = $INC{$module};
    $path = './' . $path if !File::Spec->file_name_is_absolute($path);

    $^W = 1 if $ENV{'PERLDOCDEBUG'};
    pop @INC if $INC[-1] eq '.';
    require Pod::Perldoc;
    local @ARGV = ($path);
    exit(Pod::Perldoc->run());
}

1;
