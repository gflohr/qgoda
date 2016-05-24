#! /usr/bin/env perl # -*- perl -*-

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
            bugtracker => 'https://rt.perl.org/rt3/',
            homepage   => "http://www.guido-flohr.net/en/projects#qgoda",
        },
        optional_features => {
            markdown => {
                description => "Markdown to HTML translation",
                prereqs => {
                    runtime => {
                        requires => {
                            'Text::Markdown' => '1.000031'
                        }
                    }
                }
            },
            tt => {
                description => "Support for Template Toolkit templates",
                prereqs => {
                    runtime => {
                        requires => {
                            'Template' => '2.26'
                        }
                    }
                }
            }
        },
        release_status => 'unstable'
    } unless $ExtUtils::MakeMaker::VERSION < 6.46;

WriteMakefile (
    NAME                => 'Qgoda',
    VERSION_FROM	    => 'lib/Qgoda.pm',
    ABSTRACT            => 'Qgoda static site generator',
    AUTHOR              => 'Guido Flohr <guido.flohr@cantanea.com>',
    PREREQ_PM => {
        'Date::Parse' => 2.30,
        'Locale::TextDomain' => 1.24,
    },
    EXE_FILES => ['qgoda'],
    PL_FILES => {},
    (MM->can ('signature_target') ? (SIGN => 1) : ()),
    LICENSE => 'gpl_3',
    @extra
);

sub MY::postamble {
   	q ( 
all :: ReleaseNotes

ReleaseNotes: NEWS
	cat NEWS >$@
	);
}
