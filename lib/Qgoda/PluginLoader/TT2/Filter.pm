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

sub new {
	my ($class, $plugin_data) = @_;

    use Data::Dumper;
    print Dumper $plugin_data;

    eval {
        package Qgoda::TT2::Plugin::Filter::Pygments;
    	
        use strict;
        
        use base qw(Template::Plugin::Filter);
        
        sub filter {
            return 'TODO';	
        }
        
        1;	
    };

    require Qgoda::TT2::Plugin::Filter::Pygments;
    
    my $self = '';
    
    bless \$self, $class;
}

1;
