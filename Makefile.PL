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

use 5.7.3;
use ExtUtils::MakeMaker;

push @extra, 'META_MERGE' => {
        resources => {
        	# Does not work at the moment.
            #repository => {
            #	type =>'git',
            #    url => 'git://github.com/gflohr/qgoda.git',
            #    web => 'https://github.com/gflohr/qgoda',
            #},
            repository => 'git://github.com/gflohr/qgoda.git',
            bugtracker => 'https://github.com/gflohr/qgoda/issues',
            homepage   => "http://www.qgoda.net/",
        },
        release_status => 'unstable'
    } unless $ExtUtils::MakeMaker::VERSION < 6.46;

WriteMakefile (
    NAME                => 'Qgoda',
    VERSION_FROM	    => 'lib/Qgoda.pm',
    ABSTRACT            => 'Qgoda static site generator',
    AUTHOR              => 'Guido Flohr <guido.flohr@cantanea.com>',
    PREREQ_PM => {
        'Archive::Extract' => 0,
        'File::HomeDir' => 0,
        'File::Globstar' => '0.4',
        'Date::Parse' => '2.30',
        'Locale::TextDomain' => '1.28',
        'Git' => 0,
        'AnyEvent' => '7.12',
        'AnyEvent::Filesys::Notify' => '1.21',
        'AnyEvent::Open3::Simple' => '0.86',
        'JSON' => '2.90',
        'HTML::TreeBuilder' => '5.03',
        'Text::Unidecode' => '1.27',
        'Text::Markdown::Hoedown' => '1.02',
        'Template' => '2.26',
        'Template::Plugin::Gettext' => '0.2',
        # The pure Perl YAML has problems parsing comments and is not
        # sufficient.
        'YAML::LibYAML' => '0.63',
        # But it _is_ needed for pretty printing the output.
        'YAML' => 0,
        'File::Copy::Recursive' => '0.38',
        'Hook::LexWrap' => '0.25',
        'Data::Walk' => '2.0',
        'IPC::Signal' => 0,
        'Term::ANSIColor' => '4.04',
        'Locale::XGettext' => '0.3',
        'List::Util' => '1.45',
    },
    EXE_FILES => ['qgoda'],
    PL_FILES => {},
    (MM->can ('signature_target') ? (SIGN => 1) : ()),
    LICENSE => 'gpl_3',
    @extra
);

package ExtUtils::MakeMaker;

sub install {
    my (@args) = @_;

    use Data::Dumper;
    die Dumper \@args;
}

package MY;

use strict;

use IO::Handle;

sub postamble {
    my ($self) = @_;

    my @post;
    if (-e 'maintainer.mk') {
        open my $fh, '<maintainer.mk'
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
