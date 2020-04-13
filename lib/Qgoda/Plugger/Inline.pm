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

package Qgoda::Plugger::Inline;

use strict;

use Locale::TextDomain qw(qgoda);
use Inline;

use Qgoda;

use base qw(Qgoda::Plugger);

sub new {
    my ($class, $data) = @_;

    my $self = bless $data, $class;

    return $self;
}

sub language {
    my ($self) = @_;

    my $language = ref $self;
    $language =~ s/^Qgoda::Plugger::Inline:://;

    return $language;
}

sub compile {
    my ($self) = @_;

    my $language = $self->language;

    my %config;

    if ($ENV{"QGODA_DEBUG_$language"}) {
        $config{print_version} = 1;
        $config{print_info} = 1;
    }

    my $namespace = $self->{plugin_loader}->namespace($self);
    require Data::Dumper;
    my $args = Data::Dumper::Dumper([$self->{main}, %config]);
    $args =~ s{.*?= \[}{};
    $args =~ s{\];.*?$}{};

    return sub {
        eval <<EOF;
package $namespace;

Inline->bind($language => $args);

\$SIG{INT} = 'DEFAULT';
EOF
    };
}

1;
