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

	# Try to find either yarn or npm in $PATH.
	my $preferred_package_manager = $ENV{QGODA_PACKAGE_MANAGER} || '';
	my $package_manager;
	my $here = abs_path;
	my $libdir = File::Spec->catdir($here, 'lib');
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
# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.012.
use strict;
use warnings;

use 5.018;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "The Qgoda Static Site Generator",
  "AUTHOR" => "Guido Flohr <guido.flohr\@cantanea.com>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Qgoda",
  "EXE_FILES" => [
    "bin/qgoda"
  ],
  "LICENSE" => "gpl",
  "MIN_PERL_VERSION" => "5.018",
  "NAME" => "Qgoda",
  "PREREQ_PM" => {
    "AnyEvent" => 0,
    "AnyEvent::Filesys::Notify" => 0,
    "AnyEvent::Handle" => 0,
    "AnyEvent::Loop" => 0,
    "Archive::Extract" => 0,
    "Carp" => 0,
    "Cpanel::JSON::XS" => 0,
    "Cwd" => 0,
    "Data::Dumper" => 0,
    "Data::Walk" => "2.00",
    "Date::Parse" => 0,
    "Encode" => "2.12",
    "Exporter" => 0,
    "File::Basename" => 0,
    "File::Copy" => 0,
    "File::Copy::Recursive" => 0,
    "File::Find" => 0,
    "File::Globstar" => 0,
    "File::Globstar::ListMatch" => 0,
    "File::HomeDir" => 0,
    "File::Path" => 0,
    "File::Spec" => 0,
    "File::Temp" => 0,
    "Filter::Util::Call" => 0,
    "Getopt::Long" => "2.36",
    "Git" => 0,
    "HTML::Parser" => 0,
    "HTML::TreeBuilder" => 0,
    "Hook::LexWrap" => 0,
    "IO::File" => 0,
    "IO::Handle" => 0,
    "IO::Interactive" => 0,
    "IPC::Open3" => 0,
    "IPC::Signal" => 0,
    "Inline" => 0,
    "JSON" => "2.0",
    "JSON::PP" => 0,
    "JavaScript::Duktape::XS" => 0,
    "LWP::UserAgent" => 0,
    "List::Util" => "1.45",
    "Locale::Messages" => 0,
    "Locale::TextDomain" => "1.28",
    "Locale::Util" => 0,
    "Locale::XGettext" => 0,
    "Locale::gettext_dumb" => 0,
    "MIME::Base64" => 0,
    "POSIX" => 0,
    "Pod::Perldoc" => 0,
    "Scalar::Util" => 0,
    "Storable" => 0,
    "Symbol" => 0,
    "Template" => 0,
    "Template::Constants" => 0,
    "Template::Plugin" => 0,
    "Template::Plugin::Filter" => 0,
    "Template::Plugin::Gettext" => "0.6",
    "Template::Provider" => 0,
    "Template::Stash" => 0,
    "Term::ANSIColor" => 0,
    "Text::Markdown" => 0,
    "Text::Markdown::Hoedown" => 0,
    "Text::Unidecode" => 0,
    "Time::HiRes" => 0,
    "URI" => 0,
    "URI::Escape" => 0,
    "URI::file" => 0,
    "URI::http" => 0,
    "YAML" => 0,
    "YAML::XS" => "0.67",
    "base" => 0,
    "boolean" => 0,
    "constant" => 0,
    "integer" => 0,
    "overload" => 0,
    "strict" => 0,
    "vars" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Test::More" => 0
  },
  "VERSION" => "v0.9.3",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "AnyEvent" => 0,
  "AnyEvent::Filesys::Notify" => 0,
  "AnyEvent::Handle" => 0,
  "AnyEvent::Loop" => 0,
  "Archive::Extract" => 0,
  "Carp" => 0,
  "Cpanel::JSON::XS" => 0,
  "Cwd" => 0,
  "Data::Dumper" => 0,
  "Data::Walk" => "2.00",
  "Date::Parse" => 0,
  "Encode" => "2.12",
  "Exporter" => 0,
  "File::Basename" => 0,
  "File::Copy" => 0,
  "File::Copy::Recursive" => 0,
  "File::Find" => 0,
  "File::Globstar" => 0,
  "File::Globstar::ListMatch" => 0,
  "File::HomeDir" => 0,
  "File::Path" => 0,
  "File::Spec" => 0,
  "File::Temp" => 0,
  "Filter::Util::Call" => 0,
  "Getopt::Long" => "2.36",
  "Git" => 0,
  "HTML::Parser" => 0,
  "HTML::TreeBuilder" => 0,
  "Hook::LexWrap" => 0,
  "IO::File" => 0,
  "IO::Handle" => 0,
  "IO::Interactive" => 0,
  "IPC::Open3" => 0,
  "IPC::Signal" => 0,
  "Inline" => 0,
  "JSON" => "2.0",
  "JSON::PP" => 0,
  "JavaScript::Duktape::XS" => 0,
  "LWP::UserAgent" => 0,
  "List::Util" => "1.45",
  "Locale::Messages" => 0,
  "Locale::TextDomain" => "1.28",
  "Locale::Util" => 0,
  "Locale::XGettext" => 0,
  "Locale::gettext_dumb" => 0,
  "MIME::Base64" => 0,
  "POSIX" => 0,
  "Pod::Perldoc" => 0,
  "Scalar::Util" => 0,
  "Storable" => 0,
  "Symbol" => 0,
  "Template" => 0,
  "Template::Constants" => 0,
  "Template::Plugin" => 0,
  "Template::Plugin::Filter" => 0,
  "Template::Plugin::Gettext" => "0.6",
  "Template::Provider" => 0,
  "Template::Stash" => 0,
  "Term::ANSIColor" => 0,
  "Test::More" => 0,
  "Text::Markdown" => 0,
  "Text::Markdown::Hoedown" => 0,
  "Text::Unidecode" => 0,
  "Time::HiRes" => 0,
  "URI" => 0,
  "URI::Escape" => 0,
  "URI::file" => 0,
  "URI::http" => 0,
  "YAML" => 0,
  "YAML::XS" => "0.67",
  "base" => 0,
  "boolean" => 0,
  "constant" => 0,
  "integer" => 0,
  "overload" => 0,
  "strict" => 0,
  "vars" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
