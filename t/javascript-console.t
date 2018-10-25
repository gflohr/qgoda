#! /usr/bin/env perl # -*- perl -*-

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

use strict;

use Test::More;

use Qgoda::JavaScript::Environment;
use YAML::XS 0.67;

# Test that console.log() and console.err() use tied Perl streams.
my $env = Qgoda::JavaScript::Environment->new(global => 'lib');

my $stdout = tie *STDOUT, 'MyConsole';

$env->run(<<'EOF');
console.log('log');
EOF

is $stdout->buffer, "log\n"; 

done_testing;

package MyConsole;

use strict;

sub TIEHANDLE {
    bless { __buffer => '' }, shift;
}

sub WRITE {
    my ($self, $buffer, $length, $offset) = @_;

    $length ||= length $buffer;
    $offset ||= 0;
    my $chunk = substr $buffer, $offset, $length;

    $self->{__buffer} .= $chunk;

    return length $chunk;
}

sub PRINT {
    my ($self, @chunks) = @_;

    return $self->WRITE (join $,, @chunks);
}

sub CLOSE {
    shift;
}

sub UNTIE {
    shift->CLOSE;
}

sub buffer {
	my ($self) = @_;

    my $buffer = $self->{__buffer};
	$self->{__buffer} = '';

	return $buffer;
}
