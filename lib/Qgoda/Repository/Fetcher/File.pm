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

package Qgoda::Repository::Fetcher::File;

use strict;

use Locale::TextDomain qw(com.cantanea.qgoda);
use File::Copy::Recursive qw(dircopy);
use File::Spec;

use Qgoda;

use base qw(Qgoda::Repository::Fetcher);

sub fetch {
    my ($self, $uri, $destination) = @_;

    my $logger = Qgoda->new->logger;
    
    my $path = $uri->file;
    if (-d $path) {
        if (!dircopy $path, $destination) {
            $logger->fatal(__x("error copying '{src}' to '{dest}': {error}",
                               src => $path, dest => $destination, 
                               error => $!));
        }

        return $destination;
    } else {
        $logger->fatal("cannot uncompress ...");
    }
}

1;
