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

package Qgoda::PluginLoader::TT2::Filter;

use strict;

my $singleton;

sub new {
    my ($class) = @_;
    
    return $singleton if $singleton;

    my $self = {
        __modules => {}
    };

    bless $self, $class;
}

sub addPlugin {
    my ($self, $plugin_data) = @_;

    my $class_name = 'Qgoda::Plugin::TT2::Filter::' . $plugin_data->{module};
    my $module_name = $class_name;
    $module_name =~ s{(?:::|\')}{/}g;
    $module_name .= '.pm';

    $self->{__modules}->{$module_name} = $plugin_data;

    no strict 'refs';

    *{"${class_name}::new"} = sub {
        my ($class, $args, $config) = @_;

        my $self = {
            _DYNAMIC => 1
        };

        bless $self, $class;
    };

    return $self;
}

sub Qgoda::PluginLoader::TT2::Filter::INC {
    my ($self, $filename) = @_;

    return if !exists $self->{__modules}->{$filename};

    my $data = '1';

    open my $fh, '<', \$data;

    return $fh;
}

unshift @INC, Qgoda::PluginLoader::TT2::Filter->new;
