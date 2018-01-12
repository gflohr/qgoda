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

package Qgoda::Util::Translate;

use strict;

use Locale::TextDomain qw(qgoda);
use Locale::gettext_dumb;
use Storable qw(dclone);
use Scalar::Util qw(reftype);
use Template::Stash;
use YAML::XS;
use File::Globstar qw(globstar);

use Qgoda::Util qw(empty merge_data flatten2hash front_matter);
use Qgoda::Splitter;

use base 'Exporter';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(translate_front_matter translate_body get_masters);

sub __translate_property {
    my ($property, $value, $textdomain) = @_;

    my $hash = flatten2hash {$property => $value};

    my $stash = Template::Stash->new({});
    foreach my $key (keys %$hash) {
        $stash->set($key,
                    Locale::gettext_dumb::dpgettext($textdomain, $key,
                                                    $hash->{$key}));
    }

    return $stash->get($property);
}

sub translate_front_matter {
    my ($asset) = @_;

    my $qgoda = Qgoda->new;
    my $config = $qgoda->config;
    my $relpath = $asset->{relpath};

    my $lingua = $asset->{lingua};
    die __"lingua not set" if empty $lingua;

    my $master_relpath = $asset->{master};
    $master_relpath =~ s{^/}{};
    $master_relpath = 'index.html' if empty $master_relpath;

    my $front_matter = front_matter $master_relpath;
    die __x("cannot read front matter from master '{path}': {error}",
            path => $master_relpath, error => $!)
        if !defined $front_matter;
    
    my $master = dclone YAML::XS::Load($front_matter);

    my @translate;
    if (!empty $asset->{translate}) {
        if (ref $asset->{translate} && 'ARRAY' eq reftype $asset->{translate}) {
            @translate = @{$asset->{translate}};
        } else {
            @translate = ($asset->{translate});
        }
    }

    my $textdomain = $config->{po}->{textdomain};

    local %ENV = %ENV;
    $ENV{LANGUAGE} = $lingua;
    foreach my $prop (@translate) {
        $asset->{$prop} = __translate_property($prop, $master->{$prop},
                                               $textdomain);
    }
    merge_data $master, $asset;

    %{$_[0]} = %$master;

    return 1;
}

sub translate_body {
    my ($asset) = @_;

    my $qgoda = Qgoda->new;
    my $config = $qgoda->config;
    my $relpath = $asset->{relpath};

    my $lingua = $asset->{lingua};
    die __"lingua not set" if empty $lingua;

    my $master_relpath = $asset->{master};
    $master_relpath =~ s{^/}{};
    $master_relpath = 'index.html' if empty $master_relpath;

    my $front_matter = front_matter $master_relpath;
    die __x("cannot read front matter from master '{path}': {error}")
        if !defined $front_matter;
    
    my $splitter = Qgoda::Splitter->new($master_relpath);

    local %ENV = %ENV;
    $ENV{LANGUAGE} = $lingua;

    my $textdomain = $config->{po}->{textdomain};

    my $translate = sub {
        my ($msgid) = @_;

        # FIXME! Strip off comment!
        return Locale::gettext_dumb::dgettext($textdomain, $msgid);
    };

    return $splitter->reassemble($translate);
}

sub get_masters {
    my ($self) = @_;

    my $qgoda = Qgoda->new;
    $qgoda->initPlugins;
    $qgoda->initAnalyzers;
    my $config = $qgoda->config;
    my $logger = $qgoda->logger;
    my $site = Qgoda::Site->new($config);
    $qgoda->setSite($site);
    $qgoda->scan($site, 'just find');

    my %mdextra;
    my %mddelete;

    my $mdextra = $config->{po}->{mdextra} || [];
    foreach my $pattern (@$mdextra) {
        my $negated = $pattern =~ s/^!//;
        # Force path to be relative.
        $pattern =~ s{^/+}{};
        my @files = globstar $pattern;
        foreach my $found (@files) {
            if (-d $found) {
                # Skip directory.
            } elsif ($negated) {
                $logger->debug(__x("removing markdown file '{filename}'",
                                   filename => $found));
                delete $mdextra{$found};  
                $mddelete{$found} = 1;              
            } else {
                $logger->debug(__x("adding markdown file '{filename}'",
                                   filename => $found));
                $mdextra{$found} = 1;
                delete $mddelete{$found};
            }
        }
    }

    foreach my $delete (keys %mddelete) {
        my $path = File::Spec->rel2abs($delete);
        my $asset = $site->{assets}->{$path} or next;
        $site->removeAsset($asset);
    }

    foreach my $relpath (keys %mdextra) {
        my $path = File::Spec->abs2rel($relpath);
        next if $site->{assets}->{$path};

        $logger->debug(__x("creating asset object for '{filename}'",
                           filename => $relpath));
        $site->addAsset(Qgoda::Asset->new($path, $relpath));
    }

    $qgoda->analyze($site);

    my %masters;
    foreach my $asset (values %{$site->{assets}}) {
        next if empty $asset->{master};

        my $master = $asset->{master};
        $master =~ s{^/+}{};
        $masters{$master}->{$asset->getPath} = $asset;
    }

    return %masters;
}


1;
