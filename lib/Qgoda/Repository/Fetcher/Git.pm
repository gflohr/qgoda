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

package Qgoda::Repository::Fetcher::Git;

use strict;

use Locale::TextDomain qw(com.cantanea.qgoda);
use Git;
use File::Path qw(rmtree);

use Qgoda;

use base qw(Qgoda::Repository::Fetcher);

sub fetch {
    my ($self, $uri, $destination) = @_;

    my $logger = Qgoda->new->logger;

    $logger->debug(__x("cloning repository '{repository}'",
                       repository => $uri));

    # This will die in case of an error.
    Git::command('clone', '--depth', '1', $uri, $destination);

    my $gitdir = File::Spec->catfile($destination, '.git');
    $logger->debug(__x("deleting '{directory}'",
                       directory => $gitdir));

    rmtree $gitdir, { error => \my $err };
    if (@$err) {
        for my $diag (@$err) {
            my ($file, $message) = %$diag;
            if ($file eq '') {
                $logger->error($message);
            } else {
                $logger->error(__x("error deleting '{file}': {error}",
                                   file => $file, error => $!));
            }
        }
        $logger->fatal(__"giving up after previous errors");
    }

    return $destination;
}

1;
