#! /usr/bin/env perl

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

package MY;

use strict;

use IO::Handle;
use Cwd qw(abs_path);
use File::Spec;

sub postamble {
    my ($self) = @_;

	my @post;

$DB::single = 1;
	# Try to find either yarn or npm in $PATH.
	my $preferred_package_manager = $ENV{QGODA_PACKAGE_MANAGER} || '';
	my $package_manager;
	my $here = abs_path;
	my $libdir = File::Spec->catdir($here, 'lib', 'Qgoda');
	chdir $libdir || die "cannot cd to '$libdir': $!";
	if ($preferred_package_manager ne 'npm') {
		my $pm = $ENV{QGODA_YARN} || 'yarn';
		print "Trying '$pm install' for loading JavaScript modules.\n";
		my @cmd = ($pm, 'install');
		if (0 == system @cmd) {
			$package_manager = 'yarn';
		} else {
			print STDERR "system '@cmd' failed: ";
			if ($? == -1) {
				print STDERR "failed to execute: $!\n";
			} elsif ($? & 127) {
				printf STDERR "child died with signal %d, %s coredump\n",
					($? & 127), ($? & 128) ? 'with' : 'without';
			} else {
				printf STDERR "child exited with value %d\n", $? >> 8;
			}
		}
	}

	if (!$package_manager && $preferred_package_manager ne 'yarn') {
		my $pm = $ENV{QGODA_NPM} || 'npm';
		print "Trying '$pm install' for loading JavaScript modules.\n";
		my @cmd = ($pm, 'install');
		if (0 == system @cmd) {
			$package_manager = 'npm';
		} else {
			print STDERR "system '@cmd' failed: ";
			if ($? == -1) {
				print STDERR "failed to execute: $!\n";
			} elsif ($? & 127) {
				printf STDER "child died with signal %d, %s coredump\n",
					($? & 127), ($? & 128) ? 'with' : 'without';
			} else {
				printf STDERR "child exited with value %d\n", $? >> 8;
			}
		}
	}

	if (!$package_manager) {
		die <<'EOF';
Neither a working 'yarn' or 'npm' installation was found on your system!
You can try to build Qgoda again after setting one of the following
environment variables:

	QGODA_PACKAGE_MANAGER:
		Either 'yarn' or 'npm' if you want to force usage of
		of the two.  Leave empty if you want to try both.
	QGODA_YARN:
		Path to a working 'yarn' or empty if you want to use
		the 'yarn' command in your $PATH.
	QGODA_NPM:
		Path to a working 'npm' or empty if you want to use
		the 'npm' command in your $PATH.

EOF
	}

	chdir $here or die "cannot cd to '$here': $!";

    if (-e 'maintainer.mk') {
        open my $fh, '<', 'maintainer.mk'
            or die "Cannot open 'maintainer.mk': $!\n";
        local $/;
        push @post, <$fh>;
    }

    return join "\n", @post;
}

sub __yarnInstall {
	my ($self) = @_;

	return;
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

        return qq{"$inner"};
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
