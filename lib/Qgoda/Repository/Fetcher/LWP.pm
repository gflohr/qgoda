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

package Qgoda::Repository::Fetcher::LWP;

use strict;

use Locale::TextDomain qw(com.cantanea.qgoda);
use LWP::UserAgent;
use File::Temp;

use Qgoda;
use Qgoda::Util qw(archive_extender);

use base qw(Qgoda::Repository::Fetcher::File);

sub fetch {
    my ($self, $uri, $destination) = @_;

    my $logger = Qgoda->new->logger;

    # FIXME! More configuration option needed here.
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;
    $ua->show_progress(1);

    $logger->info(__x("downloading '{uri}' with lwp-perl"), uri => $uri);

    my $response = $ua->get($uri);
    $logger->fatal(__x("error downloading '{uri}': {error}",
                       uri => $$uri,
                       error => $response->status_line))
        if $response->is_error;

    my $fh = File::Temp->new(SUFFIX => archive_extender $uri->path);
    my $path = $fh->filename;

    # Leave errors to the extractor.
    print $fh $response->decoded_content;

    return $self->_extractArchive($path, $destination);
}

1;
