#! /bin/false

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

# Included snippet for Makefile.PL.

use strict;

use File::Spec;

sub empty(;$);
sub check_for_pm($);

# Is this a git checkout or a regular installation?
my $is_git = -e '.git';
my $qgoda_dir = File::Spec->catdir('lib', 'Qgoda');
my $package_json = File::Spec->catfile($qgoda_dir, 'package.json');
my $node_modules = File::Spec->catdir($qgoda_dir, 'node_modules');
my $npm_installed = File::Spec->catfile($qgoda_dir, 'npm_installed');

# Determine whether to use yarn, npm, or something user supplied.
my $npm;
if (empty $ENV{QGODA_PACKAGE_MANAGER}) {
	if (check_for_pm 'yarn') {
		$npm = ('yarn');
	} elsif (check_for_pm 'npm') {
		$npm = 'npm';
	} else {
		die <<'EOF';
*** error: Neither a working 'yarn' or 'npm' installation was found on your
system! You can try to build Qgoda again after setting the environment variable
QGODA_PACKAGE_MANAGER to either a working "yarn" or "npm".
EOF
	}
} else {
	$npm = $ENV{QGODA_PACKAGE_MANAGER};

	# We support space characters and double quotes in the name.  Everything
	# else will probably fail.
	if ($npm =~ s{([ "])}{\\$1}g) {
		$npm = qq{"$npm"};
	}
}

my $package_lock_warning = '';
if ($npm =~ /yarn/) {
	$package_lock_warning = <<'EOF';
$(NOECHO) $(ECHO) Please ignore warnings about 'package-lock.json' being found.
EOF
	$package_lock_warning .= "\t";
}

sub empty(;$) {
	my ($what) = @_;

	$what = $_ if !@_;

	return if defined $what && length $what;

	return 1;
}

sub check_for_pm($) {
	my ($pm) = @_;

	print "Checking for $pm ... ";
	autoflush STDOUT, 1;
	return if 0 != system $pm, '--version';

	return 1;
}

package MY;

use strict;

use IO::Handle;
use Cwd qw(abs_path);
use File::Spec;

sub postamble {
	my ($self) = @_;

	my @post;

	push @post, <<EOF;
QGODA_DIR = $qgoda_dir
NPM = $npm
PACKAGE_JSON = $package_json
NODE_MODULES = $node_modules
NPM_INSTALLED = $npm_installed

.PHONY: js_to_blib

\$(NPM_INSTALLED): \$(PACKAGE_JSON)
	${package_lock_warning}cd \$(QGODA_DIR) && \\
	\$(NPM) install && \\
	\$(TOUCH) npm_installed

js_to_blib: \$(FIRST_MAKEFILE) $npm_installed
	\$(NOECHO) \$(ABSPERLRUN) JS_TO_BLIB "\$(INST_LIB)/auto" \$(PERM_DIR) 2304
EOF

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

		return qq{"$inner"};
	};

	unless ($ENV{QGODA_NO_INSTALL_CHECK}) {
		my $installdirs = $self->{INSTALLDIRS};
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
***   $script_location
***
*** which is not in your search PATH for executables and will not be
*** found from the command-line.  The easiest way to fix this is to
*** re-run the command like this:
***
***   $cmd
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

package MM;

use strict;

use File::Spec;

sub pm_to_blib {
	my ($self) = @_;

	# Make pm_to_blib depend on our phony js_to_blib target.
	my $code = $self->SUPER::pm_to_blib(@_);
	$code =~ s{^(pm_to_blib.*)}{$1 js_to_blib lib/Qgoda/npm_installed}m;

	return $code;
}

sub realclean {
	my ($self) = @_;

	my $npm_installed = File::Spec->catfile('$(QGODA_DIR)', 'npm_installed');
	my $node_modules = File::Spec->catdir('$(QGODA_DIR)', 'node_modules');
	my $code = $self->SUPER::realclean(@_);
	$code =~ s/[ \t\r\n]*$/\n/;
	$code .= "\t\- \$(RM_F) $npm_installed\n";
	$code .= "\t\- \$(RM_RF) $node_modules\n";

	return $code;
}

package main;
