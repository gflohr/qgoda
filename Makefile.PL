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
        'File::Globstar::ListMatch' => 0,
        'Date::Parse' => '2.30',
        'Locale::TextDomain' => '1.24',
        'Git' => 0,
        'AnyEvent' => '7.12',
        'AnyEvent::Filesys::Notify' => '1.21',
        'AnyEvent::Open3::Simple' => '0.86',
        'JSON' => '2.90',
        'HTML::TreeBuilder' => '5.03',
        'Text::Unidecode' => '1.27',
        'Text::Markdown' => '1.000031',
        'Template' => '2.26',
        'Template::Plugin::Gettext' => '0.1',
        # The pure Perl YAML has problems parsing comments and is not
        # sufficient.
        'YAML::LibYAML' => '0.63',
        'File::Copy::Recursive' => '0.38',
        'Hook::LexWrap' => '0.25',
        'Data::Walk' => '2.0',
        'IPC::Signal' => 0,
    },
    EXE_FILES => ['qgoda'],
    PL_FILES => {},
    (MM->can ('signature_target') ? (SIGN => 1) : ()),
    LICENSE => 'gpl_3',
    @extra
);

package MY;

use File::ShareDir::Install;

sub postamble {
    my ($self) = @_;

    if (-e 'maintainer.mk') {
        open my $fh, '<maintainer.mk'
            or die "Cannot open 'maintainer.mk': $!\n";
        local $/;
        push @post, <$fh>;
    }
    
    return join "\n", @post;
}
