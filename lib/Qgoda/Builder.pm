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

package Qgoda::Builder;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');
use POSIX qw(setlocale);
use Locale::Util qw(web_set_locale);
use File::Spec;

use Qgoda::Util qw(empty read_file read_body write_file);

sub new {
    my $self = '';
    bless \$self, shift;
}

sub build {
    my ($self, $site) = @_;

    my $logger = $self->logger;
    $logger->debug(__"start building posts");
    my $config = $site->{config};

    my $qgoda = Qgoda->new;
    my $errors = 0;

    # 1st pass, usually Markdown.
    ASSET: foreach my $asset ($site->getAssets) {
        my $saved_locale = setlocale(POSIX::LC_ALL());
        eval {
            local $SIG{__WARN__} = sub {
                my ($msg) = @_;
                $logger->warning("$asset->{path}: $msg");
            };

            $logger->debug(__x("processing asset '/{relpath}'",
                               relpath => $asset->getRelpath));
            $self->processAsset($asset, $site);
        };
        if ($@) {
            ++$errors;
            my $path = $asset->getPath;
            $logger->error("$path: $@");
        }
        setlocale(POSIX::LC_ALL(), $saved_locale);
    }

    $site->computeRelations;

    # 2nd pass, usually HTML.
    ASSET: foreach my $asset ($site->getAssets) {
        my $saved_locale = setlocale(POSIX::LC_ALL());
        eval {
            local $SIG{__WARN__} = sub {
                my ($msg) = @_;
                $logger->warning("$asset->{path}: $msg");
            };

            $logger->debug(__x("wrapping asset '/{relpath}'",
                               relpath => $asset->getRelpath));
            $self->wrapAsset($asset, $site);

            $self->saveArtefact($asset, $site, $asset->{location});
            $logger->debug(__x("successfully built '{location}'",
                               location => $asset->{location}));
        };
        if ($@) {
            ++$errors;
            my $path = $asset->getPath;
               $logger->error("$path: $@");
        }
        setlocale(POSIX::LC_ALL(), $saved_locale);
    }

    if ($errors) {
        $logger->error(">>>>>>>>>>>>>>>>>>>");
        $logger->error(__nx("one artefact has not been built because of errors (see above)",
                            "{num} artefacts have not been built because of errors (see above)",
                            $errors, num => $errors)) if $errors;
        $logger->error(">>>>>>>>>>>>>>>>>>>");
    }

    return $self;
}

sub logger {
    my ($self) = @_;

    require Qgoda;
    my $logger = Qgoda->new->logger('builder');
}

sub readAssetContent {
    my ($self, $asset, $site) = @_;

    if ($asset->{raw}) {
        return read_file($asset->getPath);
    } else {
        return read_body($asset->getPath);
    }
}

sub saveArtefact {
    my ($self, $asset, $site, $permalink) = @_;

    require Qgoda;
    my $config = Qgoda->new->config;
    $permalink = '/' . $asset->getRelpath if empty $permalink;
    my $path = File::Spec->catdir($config->{outdir}, $permalink);

    my $existing = $site->getArtefact($path);
    if ($existing) {
        my $origin = $existing->getAsset;
        my $logger = $self->logger;
        $logger->warning(__x("Overwriting artefact at '{outpath}', "
                             . "origin: {origin}",
                             outpath => $path,
                             origin => $origin ? $origin->getOrigin : __"[unknown origin]"));
    }

    my $write_file = 1;
    if ($config->{compare_output}) {
        my @stat = stat $path;
        if (@stat) {
            if ($stat[7] == length $asset->{content}) {
                my $old = read_file $path;
                if (defined $old && $old eq $asset->{content}) {
                    undef $write_file;
                    $self->logger->debug(__x("Skipping unchanged file"
                                             . " '{output}'", output => $path));
                }
            }
        }
    }

    if ($write_file) {
        $site->addModified($path, $asset);
        unless (write_file $path, $asset->{content}) {
            my $logger = $self->logger;
            $logger->error(__x("error writing '{filename}': {error}",
                               filename => $path, error => $!));
            return;
        }
    }

    $site->addArtefact($path, $asset);
}

sub processAsset {
    my ($self, $asset, $site) = @_;

    my $qgoda = Qgoda->new;
    my $logger = $self->logger;

    $logger->debug(__x("processing asset '/{relpath}'",
                       relpath => $asset->getRelpath));

    my $content = $self->readAssetContent($asset, $site);
    $asset->{content} = $content;
    my @processors = $qgoda->getProcessors($asset);
    foreach my $processor (@processors) {
        my $short_name = ref $processor;
        $short_name =~ s/^Qgoda::Processor:://;
        $logger->debug(__x("processing with {processor}",
                           processor => $short_name));
        $asset->{content} = $processor->process($asset->{content},
                                                $asset, $site);
    }

    if (@processors) {
        my %postmeta = $processors[-1]->postMeta($asset->{content}, $asset,
                                                 $site);
        $asset->{excerpt} = $postmeta{excerpt} if empty $asset->{excerpt};
        $asset->{links} ||= $postmeta{links};
    }

    return $self;
}

sub wrapAsset {
    my ($self, $asset, $site) = @_;

    my $qgoda = Qgoda->new;

    my @processors = $qgoda->getWrapperProcessors($asset);
    return $self if !@processors;

    my $view = $asset->{view};
    die __"no view specified.\n" if empty $view;

    my $logger = $self->logger;
    
    my $srcdir = $qgoda->config->{srcdir};
    my $view_dir = $qgoda->config->{paths}->{views};
    my $view_file = File::Spec->join($srcdir, $view_dir, $view);
    my $content = read_file $view_file;
    die __x("error reading view '{file}': {error}.\n",
            file => $view_file, error => $!)
        if !defined $content;
    foreach my $processor (@processors) {
        my $short_name = ref $processor;
        $short_name =~ s/^Qgoda::Processor:://;
        $logger->debug(__x("wrapping with {processor}",
                           processor => $short_name));
        $content = $processor->process($content, $asset, $site);
    }

    $asset->{content} = $content;

    return $self;
}

1;

=head1 NAME

Qgoda::Builder - Default builder for Qgoda posts.
