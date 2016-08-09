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

package Template::Plugin::Pygments;

use strict;

use base qw(Template::Plugin::Filter);

sub init {
	my ($self) = @_;
	
	$self->{_DYNAMIC} = 1;
	$self->install_filter('pygments');
	
	return $self;
}

sub filter {
	my ($self, $text) = @_;
	
	return 'The text was changed.';
}

1;
