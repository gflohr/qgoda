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

package Qgoda::Command::Js;

use strict;

use Qgoda;
use Qgoda::CLI;

use Locale::TextDomain qw(qgoda);

use base 'Qgoda::Command::Javascript';

1;

=head1 NAME

qgoda js - Alias for "qgoda javascript"

=head1 DESCRIPTION

Try C<qgoda javascript --help>.

=head1 SEE ALSO

qgoda(1), L<Qgoda::Command::Javascript>

=head1 QGODA

Part of L<Qgoda|http://www.qgoda.net/>.

=cut
