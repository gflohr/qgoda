#! /bin/false

# Copyright (C) 2016-2018 Guido Flohr <guido.flohr@cantanea.com>,
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

package Qgoda::HTMLFilter::Generator;

use strict;

use Qgoda;

sub new {
    my ($class, %args) = @_;

    my $indent = exists $args{indent} ? $args{indent} : '  ';
    my $self = {
        __indent => $indent,
    };

    bless $self, $class;
}

sub end {
    my ($self, $chunk, %args) = @_;

    return $chunk if 'head' ne $args{tagname};

    $args{output} =~ /([ \t]*)/;
    my $head_indent = $1;

    my $content = "Qgoda $Qgoda::VERSION (http://www.qgoda.net/)";
    my $version = qq{<meta name="generator" content="$content" />};

    $chunk = $self->{__indent} . "$version\n$head_indent$chunk";

    return $chunk;
}

1;
