#! /bin/false

# Copyright (C) 2016-2020 Guido Flohr <guido.flohr@cantanea.com>,
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

package Qgoda;
$Qgoda::VERSION = '0.9.7';
use common::sense;

# FIXME! This assumes that we are a top-level package. Instead,
# inpect also __PACKAGE__ and adjust the directory accordingly.
use File::Basename qw(fileparse dirname);
my $package_dir = File::Spec->catdir(Cwd::abs_path(dirname __FILE__), 'Qgoda');

use base 'Exporter';
use vars qw(@EXPORT $VERSION);
@EXPORT = qw($VERSION);

use Locale::TextDomain 1.30 qw(qgoda);
use Locale::Messages;
use Locale::gettext_dumb;
use File::Find;
use Cwd;
use Scalar::Util qw(reftype blessed);
use AnyEvent;
use AnyEvent::Loop;
use AnyEvent::Handle;
use Symbol qw(gensym);
use IPC::Open3 qw(open3);
use IPC::Signal;
use POSIX qw(:sys_wait_h);
use Template::Plugin::Gettext 0.7;
use List::Util 1.45 qw(uniq);
use YAML::XS 0.67;
use AnyEvent::Filesys::Notify 1.23;
use boolean;
$YAML::XS::Boolean = 'JSON::PP';

use Qgoda::Logger;
use Qgoda::Config;
use Qgoda::Site;
use Qgoda::Asset;
use Qgoda::Analyzer;
use Qgoda::Builder;
use Qgoda::Util qw(empty strip_suffix interpolate normalize_path write_file
                   collect_defaults purify perl_class class2module trim
                   read_file);
use Qgoda::PluginUtils qw(load_plugins);

my $qgoda;

sub new {
    return $qgoda if $qgoda;

    Locale::Messages->select_package('gettext_pp');
    my ($class, $options, $params) = @_;

    $options ||= {};
    $params ||= {};

    my $self = $qgoda = bless {}, $class;

    $self->{__options} = { %$options };
    my $logger = $self->{__logger} = $self->logger;

    $self->{__config} = Qgoda::Config->new unless $params->{no_config};
    $self->{__builders} = [Qgoda::Builder->new];
    $self->{__processors} = {};
    $self->{__load_plugins} = 1;

    return $qgoda;
}

sub reset {
	undef $qgoda;
}

sub setSite {
    my ($self, $site) = @_;

    $self->{__site} = $site;

    return $self;
}

sub initPlugins {
    my ($self) = @_;

    delete $self->{__load_plugins} && load_plugins $qgoda;

    return $self;
}

sub build {
    my ($self, %options) = @_;

    $self->initPlugins;

    if (!$self->{__build_options}) {
        $self->{__build_options} = {%options};
    } elsif (!%options) {
        %options = %{$self->{__build_options}};
    }

    my $logger = $self->{__logger};
    my $config = $self->{__config};

    $logger->info(__"start building site");

    chdir $config->{srcdir}
        or $logger->fatal(__x("cannot chdir to source directory '{dir}': {error}",
                              dir => $config->{srcdir},
                              error => $!));
    my $site = Qgoda::Site->new($config);
    $self->setSite($site);

    $self->{__outfiles} = [];
    $self->scan($site);
    $self->__initVersionControlled($site)
        if !empty $config->{scm} && 'git' eq $config->{scm};

    my $textdomain = $config->{po}->{textdomain};
    my $locale_dir = File::Spec->catfile($config->{srcdir}, 'LocaleData');
    Locale::gettext_dumb::bindtextdomain($textdomain, $locale_dir);
    if (!empty $config->{po}->{textdomain} && $config->{po}->{reload}) {
        eval {
            # Delete the cached translations so that changes are immediately
            # visible.
            # It is the privilege of the author to use private variables. ;)
            delete $Locale::gettext_pp::__gettext_pp_domain_cache->{$locale_dir};
        };
    }

    $self->__analyze($site) or return;
    $self->__locate($site) or return;

    $self->__build($site, %options);

    return $self if $options{dry_run};

    my $deleted = $self->__prune($site);

    my $site = $self->getSite;
    my $modified = scalar keys %{$site->getModified};

    if (($modified + $deleted) && !empty $config->{paths}->{timestamp}) {
        my $timestamp_file = File::Spec->catfile($config->{srcdir},
                                                 $config->{paths}->{timestamp});
        if (!write_file($timestamp_file, sprintf "%d\n", time)) {
                $logger->error(__x("cannot write '{file}': {error}!",
                               file => $timestamp_file, error => $!));
        }
    }

    my $num_artefacts = $site->getArtefacts;
    $logger->info(__nx("finished building site with one artefact",
                       "finished building site with {num} artefacts",
                       $num_artefacts,
                       num => $num_artefacts));
    $logger->info(__nx("one artefact was changed and has been re-written",
                       "{num} artefacts were changed and have been re-written",
                       $modified,
                       num => $modified));
    if ($deleted) {
    $logger->info(__nx("one stale artefact has been deleted",
                       "{num} stale artefacts have been deleted",
                       $deleted,
                       num => $deleted));
    }

    return $self;
}

sub dumpAssets {
    my ($self) = @_;

    $self->build;

    # Stringify all blessed references.
    map { purify { $_->dump } } $self->getSite->getAssets;
}

sub dump {
    my ($self, %options) = @_;

    my $data = [$self->dumpAssets];

    my $format = $options{output_format};
    $format = 'JSON' if empty $format;

    if ('JSON' eq uc $format) {
        require JSON;
        print JSON::encode_json($data);
    } elsif ('YAML' eq uc $format) {
        require YAML::XS;
        print YAML::XS::Dump($data);
    } elsif ('STORABLE' eq uc $format) {
        require Storable;
        print Storable::nfreeze($data);
    } elsif ('PERL' eq uc $format) {
        require Data::Dumper;
        $Data::Dumper::Varname = 'Qgoda';
        print Data::Dumper::Dumper($data);
    } else {
        die __x("Unsupported dump output format '{format}'.\n",
                format => $format);
    }

    return $self;
}

sub watch {
    my ($self, %options) = @_;

    my $logger = $self->{__logger};

    eval {
        # An initial build failure is fatal.
        $self->build(%options);

        my $config = $self->{__config};

        $self->__startHelpers($config->{helpers});

        $self->{__stop} = AnyEvent->condvar;

        $logger->debug(__x("waiting for changes in '{dir}'",
                           dir => $config->{srcdir}));
        AnyEvent::Filesys::Notify->new(
            dirs => [$config->{srcdir}],
            interval => $config->{latency},
            parse_events => 1,
            cb => sub { $self->__onFilesysChange(@_) },
            filter => sub { $self->__filesysChangeFilter(@_) },
        );

        my $reason = $self->{__stop}->recv;
        $reason = __"no reason given!" if empty $reason;

        $logger->info(__x("terminating on demand: {reason}",
                          reason => $reason));
    };
    $logger->fatal($@) if $@;

    return $self;
}

sub stop {
    my ($self, $reason) = @_;

    if ($self->{__stop}) {
        $self->{__stop}->send($reason);
    } else {
        die $reason;
    }
}

sub __startHelpers {
    my ($self, $helpers) = @_;

    $self->{__helpers} = {};

    foreach my $helper (sort keys %{$helpers || {}}) {
        $self->__startHelper($helper, $helpers->{$helper});
    }

    return $self;
}

sub __startHelper {
    my ($self, $helper, $args) = @_;

    $args ||= [];
    $args = [$helper] if !@$args;
    my $logger = $self->logger;

    my $safe_helper = $helper;
    $safe_helper =~ s/[^a-z0-9]+/_/;

    my $log_prefix = "[helper][$helper]";

    my $exec = $ENV{"QGODA_HELPER_$safe_helper"};
    if (!empty $exec) {
        if ($>) {
            $logger->fatal($log_prefix
                           . __x("Environment variable '{variable}' ignored"
                               . " when running as root",
                               variable => "QGODA_HELPER_$helper"));
        }
        $args->[0] = $exec;
    }

    my @pretty;
    foreach my $word (@$args) {
        if ($word =~ s/([\\\"])/\\$1/g) {
            $word = qq{"$word"};
        }
        push @pretty, $word;
    }

    my $pretty = join ' ', @pretty;

    $logger->info($log_prefix . __x("starting helper: {helper}",
                                    helper => $pretty));

    my $cout = gensym;
    my $cerr = gensym;

    my $pid = open3 undef, $cout, $cerr, @$args
        or $logger->fatal($log_prefix . __x("failure starting helper: {error}",
                                            error => $!));

    $self->{__helpers}->{$pid} = {
        name => $helper,
    };

    $self->{__helpers}->{$pid}->{ahout} = AnyEvent::Handle->new(
        fh => $cout,
        on_error => sub {
            my ($handle, $fatal, $msg) = @_;

            my $method = $fatal ? 'error' : 'warning';
            $logger->$method($log_prefix . $msg);
        },
        on_read => sub {
            my ($handle) = @_;

            while ($handle->{rbuf} =~ s{(.*?)\n}{}) {
                $logger->info($log_prefix . $1);
            }
        },
    );

    $self->{__helpers}->{$pid}->{aherr} = AnyEvent::Handle->new(
        fh => $cerr,
        on_error => sub {
            my ($handle, $fatal, $msg) = @_;

            my $method = $fatal ? 'error' : 'warning';
            $logger->$method($log_prefix . $msg);
        },
        on_read => sub {
            my ($handle) = @_;

            while ($handle->{rbuf} =~ s{(.*?)\n}{}) {
                $logger->warning($log_prefix . $1);
            }
        },
    );

    return $self;
}

sub logger {
    my ($self, $prefix) = @_;

    my %args = (prefix => $prefix);
    if ($self->{__options}->{verbose}) {
        $args{debug} = 1;
    } elsif ($self->{__options}->{quiet}) {
        $args{quiet} = 1;
    }

    $args{log_fh} = \*STDERR if $self->{__options}->{log_stderr};

    return Qgoda::Logger->new(%args);
}

sub config {
    shift->{__config};
}

sub rawConfig {
	my ($self) = @_;

    # We need our own copy so that we can mess around with it.
    my $config = Qgoda::Config->new(raw => 1);

    # Poor man's Data::Structure::unbless().
    my %config = %$config;

	return \%config;
}

sub dumpConfig {
    my ($self) = @_;

    return YAML::XS::Dump($self->rawConfig);
}

sub printConfig {
	my ($self) = @_;

	my $config = $self->dumpConfig;

	print $config;

	return $self;
}

sub init {
    my ($self, $args, %options) = @_;

    require Qgoda::Init;
    Qgoda::Init->new($args, %options)->init;

    return $self;
}

sub _getProcessors {
    my ($self, @names) = @_;

    my $processors = $self->config->{processors};

    my @processors;
    foreach my $module (@names) {
        my $class_name = 'Qgoda::Processor::' . $module;

        if ($self->getProcessor($class_name)) {
            push @processors, $self->getProcessor($class_name);
            next;
        }

        $self->logger->fatal(__x("invalid processor name '{processor}'",
                                 processor => $module))
            if !perl_class $class_name;

        my $module_name = class2module $class_name;

        require $module_name;
        my $options = $processors->{options}->{$module};
        my @options;
        if (defined $options) {
            if (ref $options) {
                if ('HASH' eq reftype $options) {
                    @options = %{$options};
                } else {
                    @options = @{$options};
                }
            } else {
                @options = $options;
            }
        }

        my $processor = $class_name->new(@options);
        $self->{__processors}->{$class_name} = $processor;
        push @processors, $processor;
    }

    return @processors;
}

sub getWrapperProcessors {
    my ($self, $asset) = @_;

    my $processors = $self->config->{processors};
    my $chain_name = $asset->{wrapper};

    if (!defined $chain_name) {
        # Indirection.
          $chain_name = $asset->{chain};
        return if !defined $chain_name;
        my $chain = $processors->{chains}->{$chain_name} or return;

        $chain_name = $chain->{wrapper};
    }
    return if !defined $chain_name;

    my $chain = $processors->{chains}->{$chain_name} or return;
    my $names = $chain->{modules} or return;

    return $self->_getProcessors(@$names);
}

sub getProcessors {
    my ($self, $asset) = @_;

    my $chain_name = $asset->{chain};
    return if !defined $chain_name;
    my $processors = $self->config->{processors};
    my $chain = $processors->{chains}->{$chain_name} or return;

    my $names = $chain->{modules} or return;

    return $self->_getProcessors(@$names);
}

sub getProcessor {
    my ($self, $name) = @_;

    return $self->{__processors}->{$name};
}

sub scan {
    my ($self, $site, $just_find) = @_;

    my $logger = $self->{__logger};
    my $config = $self->{__config};

    my $outdir = $config->{paths}->{site};
    my $srcdir = $config->{srcdir};

    # Scan the source directory.
    $logger->debug(__x("scanning source directory '{srcdir}'",
                       srcdir => $config->{srcdir}));
    File::Find::find({
        wanted => sub {
            if (-f $_) {
                my $path = Cwd::abs_path($_);
                if (!$config->ignorePath($path)) {
                    my $relpath = File::Spec->abs2rel($path, $config->{srcdir});
                    my $asset = Qgoda::Asset->new($path, $relpath);
                    $site->addAsset($asset);
                }
            }
        },
        preprocess => sub {
            # Prevent descending into ignored directories.
            my $path = Cwd::abs_path($File::Find::dir);
            if ($config->ignorePath($path)) {
                return;
            } else {
                return @_;
            }
        }
    }, $config->{srcdir});

    return $self if $just_find;

    # And the output directory.
    my @outfiles;
    $self->{__outfiles} = \@outfiles;
    $logger->debug(__x("scanning output directory '{outdir}'",
                       outdir => $config->{paths}->{site}));
    File::Find::find(sub {
        if ($_ ne '.' && $_ ne '..') {
            push @outfiles, Cwd::abs_path($_);
        }
    }, $config->{paths}->{site});

    return $self;
}

sub analyze {
    my ($self) = @_;

    my $site = $self->getSite;

    my $logger = $self->logger;
    foreach my $analyzer (@{$self->{__analyzers}}) {
        my $class = ref $analyzer;
        local $SIG{__WARN__} = sub {
            my ($msg) = @_;
            $logger->warning("[$class] $msg");
        };
        $logger->debug(__x("{class} setup",
                           class => "[$class]"));
        eval {
            $analyzer->setup($site);
        };
        if ($@) {
            $logger->error("[$class] $@");
            return;
        }

        foreach my $asset ($site->getAssets) {
            my $relpath = $asset->getRelpath;
            local $SIG{__WARN__} = sub {
                my ($msg) = @_;
                $logger->warning("[$class] $relpath: $msg");
            };
            $logger->debug(__x("{class} analyzing '{relpath}'",
                            class => "[$class]", relpath => $relpath));
            eval { $analyzer->analyze($asset, $site) };
            if ($@) {
                $logger->error("[$class] $relpath: $@");
                $self->getSite->purgeAsset($asset);
            }
        }
    }

    return $self;
}

sub analyzeAssets {
    my ($self, $assets, $included) = @_;

    my $site = $self->getSite;

    my $logger = $self->logger;
    foreach my $analyzer (@{$self->{__analyzers}}) {
        my $class = ref $analyzer;
        foreach my $asset (@$assets) {
            my $relpath = $asset->getRelpath;
            local $SIG{__WARN__} = sub {
                my ($msg) = @_;
                $logger->warning("[$class] $relpath: $msg");
            };
            $logger->debug(__x("{class} analyzing '{relpath}'",
                            class => "[$class]", relpath => $relpath));
            eval { $analyzer->analyze($asset, $site, $included) };
            if ($@) {
                $logger->error("[$class] $relpath: $@");
                $self->getSite->purgeAsset($asset) if !$included;
            }
        }
    }

    return $self;
}

sub __analyze {
    my ($self, $site) = @_;

    $self->initAnalyzers if !$self->{__analyzers};

    return $self->analyze;
}

sub initAnalyzers {
    my ($self) = @_;

    my @analyzers = (Qgoda::Analyzer->new);
    $self->{__analyzers} = \@analyzers;
    my $names = $self->config->{analyzers} or return $self;

    foreach my $name (@$names) {
        my $class_name = 'Qgoda::Analyzer::' . $name;

        $self->logger->fatal(__x("invalid analyzer name '{analyzer}'",
                                 analyzer => $name))
            if !perl_class $class_name;

        my $module_name = class2module $class_name;

        require $module_name;

        my $analyzer = $class_name->new;
        push @analyzers, $analyzer;
    }

    return $self;
}

sub __build {
    my ($self, %options) = @_;

    my $site = $self->getSite;
    foreach my $builder (@{$self->{__builders}}) {
        $builder->build($site, %options);
    }

    return $self;
}

# FIXME! This should instantiate plug-ins and use them instead.
sub __prune {
    my ($self, $site) = @_;

    # Sort the output files by length first.  That ensures that we do a
    # depth first clean-up.
    my @outfiles = sort {
       length($b) <=> length($a)
    } @{$self->{__outfiles}};

    my $logger = $self->{__logger};
    my %directories;

    my $deleted = 0;
    foreach my $outfile (@outfiles) {
        if ($directories{$outfile} || $site->getArtefact($outfile)) {
            # Mark the containing directory as generated.
            my ($volume, $directory, $filename) = File::Spec->splitpath($outfile);
            my $container = File::Spec->catpath($volume, $directory, '');
            $container =~ s{/$}{};
            $directories{$container} = 1;
        } elsif (-d $outfile) {
            $logger->debug(__x("pruning directory '{directory}'",
                               directory => $outfile));
            $logger->error(__x("cannot remove directory '{directory}': {error}",
                               directory => $outfile, error => $!))
                if !rmdir $outfile;
        } else {
            ++$deleted;
            $logger->debug(__x("pruning file '{file}'",
                               file => $outfile));
            $logger->error(__x("cannot remove file '{filename}': {error}",
                               filename => $outfile, error => $!))
                if !unlink $outfile;
        }
    }

    return $deleted;
}

sub __filesysChangeFilter {
    my ($self, $filename) = @_;

    my $config = $self->{__config};

    if ($filename =~ /_stop$/ && -e $filename) {
        my $srcdir = $config->{paths}->{srcdir};
        my $relpath = File::Spec->abs2rel($filename, $srcdir);
        if ('_stop' eq $relpath) {
            my $reason = read_file $filename;
            unlink $filename;
            $self->stop(trim $reason);
        }
        return;
    }

    if ($config->ignorePath($filename, 1)) {
        my $logger = $self->{__logger};
        $logger->debug(__x("changed file '{filename}' is ignored",
                           filename => $filename));
        return;
    }

    return $self;
}

sub __onFilesysChange {
    my ($self, @events) = @_;

    my @files;

    my $logger = $self->{__logger};
    my $config = $self->{__config};

    foreach my $event (@events) {
        $logger->debug(__x("file '{filename}' has changed",
                           filename => $event->{path}));
        push @files, $event->{path};
    }

    return if !@files;

    $logger->info(__"start rebuilding site because of file system change");

    eval { $self->build };
    $logger->error($@) if $@;

    return $self;
}

sub getBuilders {
    my ($self) = @_;

    return $self->{__builders};
}

sub getSite {
    my ($self) = @_;

    return $self->{__site};
}

sub __locate {
    my ($self, $site) = @_;

    foreach my $asset ($site->getAssets) {
        $self->locateAsset($asset);
    }

    return $self;
}

sub locateAsset {
    my ($self, $asset) = @_;

    my $site = $self->getSite;

    my $logger = $self->logger;

    $logger->debug(__x("locating asset '/{relpath}'",
                       relpath => $asset->getRelpath));

    my $location = $asset->{raw} ? '/' . $asset->getRelpath
                   : $self->expandLink($asset, $site, $asset->{location});
    $logger->debug(__x("location '{location}'",
                       location => $location));
    $asset->{location} = $location;

    my ($significant, $directory) = fileparse $location;
    ($significant) = strip_suffix $significant;
    if ($significant eq $asset->{index}) {
        $asset->{'significant-path'} = $directory;
        $asset->{'significant-path'} .= '/'
            unless '/' eq substr $directory, -1, 1;
    } else {
        $asset->{'significant-path'} = $location;
    }
    my $permalink = $self->expandLink($asset, $site, $asset->{permalink}, 1);
    $logger->debug(__x("permalink '{permalink}'",
                       permalink => $permalink));
    $asset->{permalink} = $permalink;

    return $self;
}

sub expandLink {
    my ($self, $asset, $site, $link, $trailing_slash) = @_;

    my $interpolated = interpolate $link, $asset;
    return normalize_path $interpolated, $trailing_slash;
}

sub getOption {
    my ($self, $name) = @_;

    return if !exists $self->{__options}->{$name};

    return $self->{__options}->{$name};
}

sub _reload {
    my ($self) = @_;

    $self->{__config} = Qgoda::Config->new;

    return $self;
}

sub __initVersionControlled {
    my ($self, $site) = @_;

    my $logger = $self->logger;
    $logger->debug("finding files under version control (git)");

    my $config = $self->config;

    require Git;

    my $repo = Git->repository(Directory => $config->{srcdir});
    my @files = $repo->command(['ls-files'], STDERR => 0);

    # These are all relative paths.
    my $version_controlled = {
        absolute => {},
        relative => {},
    };

    my $srcdir = $config->{srcdir};
    foreach my $relpath (@files) {
        my $abspath = File::Spec->rel2abs($relpath, $srcdir);
        $version_controlled->{absolute}->{$abspath} = $relpath;
        $version_controlled->{relative}->{$relpath} = $abspath;
    }
    $self->{__version_controlled} = $version_controlled;

    my $no_scm = $self->__initNoSCMPatterns;
    foreach my $asset (values %{$site->{assets}}) {
        if (!$version_controlled->{absolute}->{$asset->getPath}) {
            my $relpath = $asset->getRelpath;
            next if $no_scm && $no_scm->match($relpath);

            $logger->debug(__x("ignoring '{relpath}': not under version control",
                               relpath => $relpath));
            $site->removeAsset($asset);
        }
    }

    return 1;
}

sub __initNoSCMPatterns {
    my ($self) = @_;

    my $config = $self->config;
    my $no_scm = $config->{'no-scm'};

    return $no_scm if blessed $no_scm;

    require File::Globstar::ListMatch;
    return $config->{'no-scm'} =
            File::Globstar::ListMatch->new($no_scm,
                                           $config->{'case-insensitive'});
}

sub versionControlled {
    my ($self, $path, $is_absolute) = @_;

    my $config = $self->config;
    return $self if !$config->{scm} || 'git' ne $config->{scm};

    $self->__initVersionControlled if !$self->{__version_controlled};

    my $key = $is_absolute ? 'absolute' : 'relative';
    return $self if $self->{__version_controlled}->{$key}->{$path};

    my $no_scm = $self->__initNoSCMPatterns or return;

    $path = File::Spec->rel2abs($path, $self->config->{srcdir});
    return $self if $no_scm->match($path);

    return;
}

sub buildOptions {
    my ($self, %options) = @_;

    if (%options) {
        $self->{__build_options} = {%options};
    }

    return %{$self->{__build_options} || {}};
}

sub nodeModules {
	my ($self) = @_;

    return join '/', $package_dir, 'node_modules';
}

sub jsout {
	my ($self, $jsout) = @_;

	if (@_ == 1) {
		$jsout = $self->{__jsout};
		$jsout = '' if empty $jsout;
		return $jsout;
	}

	$self->{__jsout} = $jsout;
}

sub jserr {
	my ($self, $jserr) = @_;

	if (@_ == 1) {
		$jserr = $self->{__jserr};
		$jserr = '' if empty $jserr;
		return $jserr;
	}

	$self->{__jserr} = $jserr;
}

sub jsreturn {
	my ($self, $value) = @_;

	if (@_ > 1) {
		$self->{__jsreturn} = $value;
	}

	return $self->{__jsreturn};
}

1;

=head1 NAME

Qgoda - The Qgoda Static Site Generator

=head1 SYNOPSIS

    qgoda --help

    open http://www.qgoda.net/

=head1 DOCUMENTATION

The documentation for Qgoda can be found at the
L<Qgoda web site|http://www.qgoda.net/>.

Other Qgoda modules that do not contain POD are for internal use only and
should not be used directly.
