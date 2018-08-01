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

package Qgoda::Analyzer;

use strict;

use Locale::TextDomain qw('qgoda');
use Date::Parse;
use File::Spec;
use File::Basename qw(fileparse);
use Scalar::Util qw(reftype);

use Qgoda::Util qw(empty yaml_error front_matter lowercase collect_defaults
                   normalize_path strip_suffix merge_data slugify
                   safe_yaml_load);
use Qgoda::Util::Date;
use Qgoda::Util::Translate qw(translate_front_matter);

sub new {
    my ($class) = @_;

    bless {}, $class;
}

sub setup {
    shift;
}

sub analyze {
    my ($self, $asset, $site, $precious) = @_;

    my $qgoda = Qgoda->new;

    my $path = $asset->getPath;
    stat $path or die __x("cannot read '{filename}': {error}",
                          filename => $path, error => $!);
    my $config = $qgoda->config;
    my $meta = collect_defaults $asset->getRelpath, $config->{defaults};

    my $front_matter = front_matter $path;
    my $front_matter_data;
    if (defined $front_matter) {
        $front_matter_data = safe_yaml_load $front_matter;
    } else {
        $front_matter_data->{raw} = 1;
    }

    merge_data $meta, $front_matter_data;

    delete $meta->{path};
    delete $meta->{relpath};
    delete $meta->{reldir};

    merge_data $asset, $meta;
    if (!empty $asset->{master}) {
        translate_front_matter $asset, $front_matter_data;
    }

    merge_data $asset, $precious if $precious;

    $self->__fillMeta($asset) if !$asset->{raw};

    my %build_options = $qgoda->buildOptions;
    if ($asset->{draft} && !$build_options{drafts}) {
        my $logger = $qgoda->logger;
        $logger->debug(__x("skipping draft '{relpath}'",
                           relpath => $asset->getRelpath));
        $site->removeAsset($asset);
    }

    my $now = time;
    if ($asset->{date} > $now && !$build_options{future}) {
        my $logger = $qgoda->logger;
        $logger->debug(__x("skipping future document '{relpath}'",
                           relpath => $asset->getRelpath));
        $site->removeAsset($asset);
    }

    return $self;
}

sub __fillMeta {
    my ($self, $asset) = @_;

    my $qgoda = Qgoda->new;
    my $logger = $qgoda->logger;
    my $config = $qgoda->config;
    my $site = $qgoda->getSite;

    my $date = $asset->{date};
    if (defined $date) {
        if ($date !~ /^-?[1-9][0-9]*$/) {
            $date = str2time $date;
            if (!defined $date) {
                $logger->error(__x("{filename}: cannot parse date '{date}'",
                                   date => $asset->{date}));
            }
        }
    }

    if (!defined $date) {
        my @stat = stat $asset->getPath;
        if (!@stat) {
            $logger->error(__x("cannot stat '{filename}': {error}",
                               filename => $asset->getPath, error => $!));
            $date = time;
        } else {
            $date = $stat[9];
        }
    }

    $asset->{date} = Qgoda::Util::Date->newFromEpoch($date);

    $self->__fillPathInformation($asset, $site);

    $asset->{title} = $asset->{basename} if !exists $asset->{title};
    $asset->{slug} = $self->__slug($asset);

    $asset->{view} = $site->getMetaValue(view => $asset);
    $asset->{type} = $site->getMetaValue(type => $asset);

    return $self;
}

sub __slug {
    my ($self, $asset) = @_;

    return slugify $asset->{title};
}

sub __fillPathInformation {
    my ($self, $asset, $site) = @_;

    my $relpath = $asset->getRelpath;
    my ($filename, $directory) = fileparse $relpath;

    $asset->{filename} = $filename;

    $directory = normalize_path $directory;
    $directory = '' if '.' eq $directory;
    $asset->{directory} = $directory;

    my ($basename, @suffixes) = strip_suffix $filename;
    $asset->{basename} = $basename;

    # For migration from Jekyll sites.
    $basename =~ s/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//;
    $asset->{basename_nodate} = $basename;

    if (empty $asset->{chain}) {
        my $trigger = $site->getTrigger(@suffixes);
        if (!empty $trigger) {
            my ($chain, $name) = $site->getChainByTrigger($trigger);
            $asset->{chain} = $name if $chain;
            if ($chain && exists $chain->{suffix}) {
                for (my $i = $#suffixes; $i >= 0; --$i) {
                    if ($suffixes[$i] eq $trigger) {
                        $suffixes[$i] = $chain->{suffix};
                        last;
                    }
                }
            }
        }
    }

    $asset->{suffixes} = \@suffixes;
    if (@suffixes) {
        $asset->{suffix} = '.' . join '.', @suffixes;
    }

    $asset->{location} = $site->getMetaValue(location => $asset);
    $asset->{permalink} = $site->getMetaValue(permalink => $asset);

    if (Qgoda->new->config->{'case-sensitive'}) {
        $asset->{location} = lc $asset->{location};
        $asset->{permalink} = lc $asset->{permalink};
    }

    $asset->{index} = $site->getMetaValue(index => $asset);

    return $self;
}

1;
