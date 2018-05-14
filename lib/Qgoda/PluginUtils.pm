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

package Qgoda::PluginUtils;

use strict;

use Locale::TextDomain qw(qgoda);
use File::Spec;
use JSON qw(decode_json);
use Scalar::Util qw(reftype);

use Qgoda::Util qw(read_file empty);

use base 'Exporter';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(load_plugins);

sub search_local_plugins($$$);
sub init_plugin($$$);

my %languages = (
    Perl => 'Qgoda::Plugger::Perl',
    Python => 'Qgoda::Plugger::Inline::Python',
);

my %types = (
    'TT2::Filter' => 'Qgoda::PluginLoader::TT2::Filter',
);

sub load_plugins {
    my ($q) = @_;

    my $logger = $q->logger('plugin-loader');

    $logger->info(__("initializing plug-ins."));

    my $config = $q->config;

    # Allow loading local Perl plug-ins.
    push @INC, $config->{srcdir};

    my $modules_dir = File::Spec->catfile($config->{srcdir}, 'node_modules');
    my %plugins = map {
        $_ => {
            package_dir => File::Spec->catfile($modules_dir, $_),
            package_json => File::Spec->catfile($modules_dir, $_,
                                                'package.json'),
        }
    } @{$config->{plugins} || []};
    foreach my $name (keys %plugins) {
        $logger->info(__x("plugin {name} found in configuration.",
                          name => $name));
    }

    my $plugin_dir = $config->{paths}->{plugins};
    search_local_plugins(\%plugins, $plugin_dir, $logger);

    while (my ($name, $plugin) = each %plugins) {
        eval {
            init_plugin $name, $plugin, $logger;
        };
        if ($@) {
            $logger->fatal(__x("plugin '{name}': {error}",
                               name => $name, error => $@));
        }
    }

    return 1;
}

sub search_local_plugins($$$) {
    my ($plugins, $plugin_dir, $logger) = @_;

    return 1 if !-e $plugin_dir;

    local *DIR;
    opendir DIR, $plugin_dir
         or $logger->fatal(__x("cannot open directory '{dir}': {error}!"));

    my @subdirs = grep {!/^[._]/} readdir DIR;
    foreach my $name (@subdirs) {
        $logger->info(__x("plugin {name} found in plugin directory.",
                          name => $name));
        my $package_dir = File::Spec->catfile($plugin_dir, $name);
        $plugins->{$name} = {
            package_dir => $package_dir,
            package_json => File::Spec->catfile($package_dir, 'package.json'),
        };
    }

    return 1;
}

sub init_plugin($$$) {
    my ($name, $plugin, $logger) = @_;

    $logger->debug(__x('initializing plugin {name}.', name => $name));

    my $package_json = $plugin->{package_json};
    my $json = read_file $package_json;
    $logger->fatal(__x('error reading plugin package file {file}: {error}!',
                       file => $package_json, error => $!))
        if !defined $json;

    my $data = decode_json $json;
    my $plugin_data = $data->{qgoda};
    $logger->fatal(__x("{file}: plugin definition (key 'qgoda') missing!",
                       file => $package_json))
        if !defined $plugin_data;
    $logger->fatal(__x("{file}: value for key 'qgoda' must be a dictionary!",
                       file => $package_json))
        if !(ref $plugin_data && 'HASH' eq reftype $plugin_data);
    $plugin_data->{main} ||= $data->{main};
    $logger->fatal(__x("{file}: 'qgoda.main' or 'main' must point to main source file!",
                       file => $package_json))
        if (empty $plugin_data->{main}
            || ref $plugin_data->{main});
    $plugin_data->{main} = File::Spec->catfile($plugin->{package_dir},
                                               $plugin_data->{main});

    my $language = $plugin_data->{language};
    $logger->fatal(__x("{file}: language (qgoda.language) missing!",
                       file => $package_json))
        if empty $language;

    my $plugger_class = $languages{$language};
    # TRANSLATORS: Language is a programming language.
    $logger->fatal(__x("{file}: unsupported language '{language}'!",
                       file => $package_json, language => $language))
        if empty $language;

    my $plugger_module = $plugger_class;
    $plugger_module =~ s{::}{/}g;
    $plugger_module .= '.pm';

    require $plugger_module;
    $plugin_data->{plugger} = $plugger_class->new($plugin_data);

    return 1 if $plugger_class->native;

    my $type = $plugin_data->{type};
    $logger->fatal(__x("{file}: type (qgoda.type) missing!",
                       file => $package_json))
        if empty $type;

    my $factory_class = $types{$type};
    # TRANSLATORS: Language is a programming language.
    $logger->fatal(__x("{file}: unsupported plugin type '{type}'!",
                       file => $package_json, type => $type))
        if empty $type;

    my $factory_module = $factory_class;
    $factory_module =~ s{::}{/}g;
    $factory_module .= '.pm';

    require $factory_module;
    my $plugin_loader = $factory_class->new;
    $plugin_data->{plugin_loader} = $plugin_loader;

    $plugin_loader->addPlugin($plugin_data);

    return 1;
}
