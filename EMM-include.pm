#! /usr/bin/env perl

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

package MY;

use IO::Handle;

sub postamble {
    my ($self) = @_;

    if (-e 'maintainer.mk') {
        open my $fh, '<', 'maintainer.mk'
            or die "Cannot open 'maintainer.mk': $!\n";
        local $/;
        push @post, <$fh>;
    }

    return join "\n", @post;
}

sub install {
    my ($self) = @_;

    my $unwrap = sub {
        my ($string, $force) = @_;

        return $string if $string !~ /^"(.*)"$/;
        my $inner = $1;
        if ($force || $inner !~ s/([\\"].)/\\$1/g) {
            return $inner;
        }

        return qq{"$innner"};
    };

    unless ($ENV{QGODA_NO_INSTALL_CHECK}) {
        my $installdirs = $self->{INSTALLDIRS};
        my $script_location;
        my $varname;
        if ('perl' eq $installdirs) {
            $varname = 'INSTALLSCRIPT';
        } elsif ('vendor' eq $installdirs) {
            $varname = 'INSTALLVENDORSCRIPT';
        } else {
            $varname = 'INSTALLSITESCRIPT';
        }

        my $script_location = $self->{$varname};

        require List::Util;
        require File::Spec;

        if (!List::Util::first(sub {
               $_ eq $script_location
            }, File::Spec->path)) {
            require File::Basename;
            my $bindir = File::Basename::dirname($unwrap->($self->{PERL}, 1));
            my $cmd = join ' ',
                      map { $unwrap->($_) }
                      $self->{PERL}, 'Makefile.PL', $self->{PERL_MM_OPT},
                      "$varname=$bindir";

            my $msg = '*' x 75 . <<EOF;
***
*** Warning! The qgoda executable will be installed in the directory
***
***    $script_location
***
*** which is not in your search PATH for executables and will not be
*** found from the command-line.  The easiest way to fix this is to
*** re-run the command like this:
***
***    $cmd
***
*** You can also install the package as usual, and read
*** http://www.qgoda.net/en/docs/installation.md for more options.
EOF
            autoflush STDERR, 1;

            warn $msg;
            foreach (1 .. 5) {
                print STDERR '*' x 15;
                sleep 1;
            }
            print STDERR "\n";
        }
    }

    return $self->SUPER::install(@_);
}
