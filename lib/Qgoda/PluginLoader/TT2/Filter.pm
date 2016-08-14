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

use Template::Plugin::Filter;

my $singleton;

sub new {
    my ($class) = @_;
    
    return $singleton if $singleton;

    $singleton = {
        __modules => {}
    };

    bless $singleton, $class;
}

sub namespace {
	my ($self, $plugin_data) = @_;
	
	return 'Template::Plugin::' . $plugin_data->{module};
}

sub addPlugin {
    my ($self, $plugin_data) = @_;

    my $class_name = $self->namespace($plugin_data);
    my $module_name = $class_name;
    $module_name =~ s{(?:::|\')}{/}g;
    $module_name .= '.pm';

    $self->{__modules}->{$module_name} = $plugin_data;

    no strict 'refs';

    *{"${class_name}::init"} = sub {
        my ($self) = @_;

        $self->{_DYNAMIC} = 1;
        $self->install_filter('pygments');
        
        $plugin_data->{plugger}->compile->();

        return $self;
    };
    
    eval <<EOF;
    package $class_name;
    
    sub filter {
    	my (\$self, \$text, \$config, \$args) = \@_;
    	
    	return pygments(\$self, \$text, \$config, \$args);
    }
EOF
    
    @{"${class_name}::ISA"} = 'Template::Plugin::Filter';
    
    return $self;
}

sub Qgoda::PluginLoader::TT2::Filter::INC {
    my ($self, $filename) = @_;

    return if !exists $self->{__modules}->{$filename};

    my $data = 'use strict; 1;';

    open my $fh, '<', \$data;

    return $fh;
}

unshift @INC, Qgoda::PluginLoader::TT2::Filter->new;
