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
use Archive::Extract;

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
    };

    return $self->_extractArchive($path, $destination);
}

sub _extractArchive {
    my ($self, $path, $destination) = @_;

    my $logger = Qgoda->new->logger;
    
    my $ae = Archive::Extract->new(archive => $path);
    $ae->extract(to => $destination)
        or $logger->fatal(__x("error extracing '{archive}' to"
                              ." '{destination}': {error}"),
                              archive => $path, 
                              destination => $destination,
                              error => $ae->error);
    
    opendir my $dh, $destination 
        or $logger->fatal(__x("error reading directory '{directory}': {error}",
                              directory => $destination,
                              error => $ae->error));
        
    my @contents = sort File::Spec->no_upwards(readdir $dh)
        or $logger->fatal(__x("archive '{archive} is empty",
                              archive => $path));

    $logger->warning(__x("archive '{archive}' has ambiguous content,"
                         . " trying first entry '{first}''",
                         archive => $path, first => $contents[0]))
        if @contents > 1;

    my $first = File::Spec->catfile($destination, $contents[0]);
    if (-d $contents[0]) {
        # Properly packaged, return the directory.
        return $contents[0];
    }

    # Archive does not unpack into a single directory.  Let's assume that
    # the directory level is simply missing.
    return $destination;
}

1;
