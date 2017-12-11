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

package Qgoda::Locale::XGettext;

use strict;

use Locale::TextDomain qw(com.cantanea.qgoda);

use Qgoda;
use Qgoda::Util qw(read_file);
use Qgoda::CLI;

use base qw(Locale::XGettext);

sub readFile {
    my ($self, $filename) = @_;

    $self->{__qgoda_files} ||= [];
    push @{$self->{__qgoda_files}}, $filename;

    return $self;
}

sub extractFromNonFiles {
    my ($self) = @_;

    my $qgoda = Qgoda->new({ 
        quiet => 1,
        verbose => 0,
        log_stderr => 1,
    });

    $qgoda->build(dry_run => 1);

    my %masters = $qgoda->getSite->getMasters;

    foreach my $master (sort keys %masters) {
        $self->__extractFromMaster($master, $masters{$master});
    }

    return $self;
}

sub __extractFromMaster {
    my ($self, $relpath, $assets) = @_;

    foreach my $asset (@$assets) {

    }

    return $self;
}

sub programName {
    $0 . ' xgettext';
}

sub canFlags { return }
sub canKeywords { return }
sub canExtractAll { return }

sub languageSpecificOptions {
    return [
        [
            '--srcdir',
            'srcdir',
            '    --srcdir=SRCDIR',
            __"the Qgoda top-level source directory (defaults to '..')",
        ]
    ];
}

sub versionInformation {
    Qgoda::CLI->displayVersion;
}
1;
