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

package Qgoda::Processor::TT2;

use strict;

use Template;
use Locale::TextDomain qw(qgoda);
use File::Spec;

use Qgoda::Util qw(empty clear_utf8_flag);

use base qw(Qgoda::Processor);

my %instances;

sub new {
    my ($class, %options) = @_;

    my $self = bless {}, $class;
    $self->{__options} = \%options;

    require Qgoda;
    my $qgoda = Qgoda->new;
    my $config = $qgoda->config;
    my $srcdir = $config->{srcdir};
    my $viewdir = $config->{paths}->{views};

    # FIXME! Merge options with those from the configuration!
    my %options = (
        INCLUDE_PATH => [File::Spec->join($srcdir, $viewdir)],
        PLUGIN_BASE => ['Qgoda::TT2::Plugin'],
        RECURSION => 1,
        # CP 1252 aka Windows-1252 defines all 8 bit characters.  We (ab)use it
        # for "binary" so that TT2 does not mess with character data.  Using
        # "utf-8" for ENCODING is a recipe for trouble.
        ENCODING => 'CP 1252'
    );
    my $scm = $config->{scm};
    if (!empty $scm && 'git' eq $scm) {
        my $provider = Qgoda::Template::GitProvider->new(%options);
        $options{LOAD_TEMPLATES} = [$provider];
    }
    $self->{__tt} = Template->new({
        %options
    }) or die Template->error;

    return $self;
}

sub process {
    my ($self, $content, $asset, $filename) = @_;

    require Qgoda;
    my $qgoda = Qgoda->new;
    my $srcdir = $qgoda->config->{srcdir};
    my $viewdir = $qgoda->config->{paths}->{views};
    my $absviewdir = File::Spec->rel2abs($viewdir, $srcdir);
    my $gettext_filename = File::Spec->abs2rel($filename, $absviewdir);
    my $vars = {
        asset => $asset,
        config => Qgoda->new->config,
        gettext_filename => $gettext_filename,
    };

    my $cooked;
    $self->{__tt}->process(\$content, $vars, \$cooked)
        or die $self->{__tt}->error, "\n" if !defined $cooked;

    return $cooked;
}

package Qgoda::Template::GitProvider;

use strict;

use base qw(Template::Provider);

sub fetch {
    my ($self, $name) = @_;

    if (!ref $name) {
    }

    return $self->SUPER::fetch($name);
}

1;

=head1 NAME

Qgoda::Processor::TT2 - Qgoda Processor For the Template Toolkit Version 2
