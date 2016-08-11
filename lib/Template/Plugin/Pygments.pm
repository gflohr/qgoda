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

use Locale::TextDomain qw(com.cantanea.qgoda);

use Qgoda;
use Qgoda::Util qw(read_file);

use base qw(Template::Plugin::Filter);

sub init {
	my ($self) = @_;
	
	$self->{_DYNAMIC} = 1;
	$self->install_filter('pygments');
	
	return $self;
}

sub filter {
	my ($self, $text, $args, $config) = @_;
	
	return pygments($self, $text, $args, $config);
}

my $code;

BEGIN {
    require File::Spec;
	
    my $q = Qgoda->new;
    my $config = $q->config;
    my $filename = File::Spec->catfile(
        $config->{srcdir}, 
        'node_modules', 
        'qgoda-plugin-pygments',
        'index.py');
    $code = read_file $filename;
    die __x("error reading '{filename}': {error}", 
            filename => $filename, error => $!)
        if !defined $code;
}

use Inline Python => $code;

1;
