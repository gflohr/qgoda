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

package Qgoda::Repository;

use strict;

use Qgoda::Util qw(read_file write_file);

use URI;

sub new {
	my ($class, $uri) = @_;

    my $self = {
        __uri => URI->new($uri)
    };

    my $protocol = $self->{__uri}->scheme;
    my %known = (
        'git' => 'Git',
        'git+ssh' => 'Git',
        'git+ssh' => 'Git',
        'git+http' => 'Git',
        'git+https' => 'Git',
        'git+file' => 'Git',
    );

    $self->{__type} = $known{$protocol};
    if ($self->{__type}) {
        if ('Git' eq $self->{__type}) {
            if ('github.com' eq $self->{__uri}->host) {
                $self->{__source} = 'Github';
            }
        }
    }
    bless $self, $class;
}

sub type { shift->{__type} }
sub source { shift->{__source} }

package URI::git;

use strict;

use base qw(URI::http);

package URI::git_Phttp;

use strict;

use base qw(URI::git);

package URI::git_Phttps;

use strict;

use base qw(URI::git);

package URI::git_Pssh;

use strict;

use base qw(URI::git);

package URI::git_Pfile;

use strict;

use base qw(URI::file);

1;