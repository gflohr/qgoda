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

package Qgoda;

use strict;

use base 'Exporter';
use vars qw(@EXPORT $VERSION);
@EXPORT = qw($VERSION);
$VERSION = '0.9.0-alpha.1';

use Locale::TextDomain qw(qgoda);
use Locale::Messages;
use Locale::gettext_dumb;
use File::Find;
use Scalar::Util qw(reftype);
use AnyEvent;
use AnyEvent::Loop;
use AnyEvent::Filesys::Notify;
use AnyEvent::Handle;
use File::Basename qw(fileparse);
use Symbol qw(gensym);
use IPC::Open3 qw(open3);
use IPC::Signal;
use POSIX qw(:sys_wait_h);
use Template::Plugin::Gettext 0.2;
use List::Util qw(uniq);

use Qgoda::Logger;
use Qgoda::Config;
use Qgoda::Site;
use Qgoda::Asset;
use Qgoda::Analyzer;
use Qgoda::Builder;
use Qgoda::Util qw(empty strip_suffix interpolate normalize_path write_file
                   collect_defaults purify perl_class class2module);
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
    $self->{__analyzers} = [Qgoda::Analyzer->new];
    $self->{__builders} = [Qgoda::Builder->new];
    $self->{__processors} = {};
    $self->{__load_plugins} = 1;

    return $qgoda;
}

sub build {
    my ($self, %options) = @_;

    delete $self->{__load_plugins} && load_plugins $qgoda;

    my $logger = $self->{__logger};
    my $config = $self->{__config};

    $logger->info(__"start building site");

    chdir $self->{__config}->{srcdir}
        or $logger->fatal(__x("cannot chdir to source directory '{dir}': {error}",
                              dir => $config->{srcdir},
                              error => $!));
    my $site = $self->{__site} = Qgoda::Site->new($config);

    $self->{__outfiles} = [];
    $self->__scan($site);

    if (!empty $config->{po}->{textdomain}) {
        my $textdomain = $config->{po}->{textdomain};
        my $locale_dir = File::Spec->catfile($config->{srcdir}, 'LocaleData');
        Locale::gettext_dumb::bindtextdomain($textdomain, $locale_dir);
        eval {
            # Delete the cached translations so that changes are immediately
            # visible.
            # It is the privilege of the author to use private variables. ;)
            delete $Locale::gettext_pp::__gettext_pp_domains->{$textdomain};
        };
    }

    $self->__analyze($site);
    $self->__locate($site);

    return $self if $options{dry_run};

    $self->__build($site);

    $self->__writePOTFile($site);

    my $deleted = $self->__prune($site);

    my $site = $self->getSite;
    my $modified = scalar keys %{$site->getModified};
    
    if ($modified + $deleted) {
        my $timestamp_file = File::Spec->catfile($config->{srcdir},
                                                 '_timestamp');
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

    $self->build(1);

    # Stringify all blessed references.
    map { purify { $_->dump } } $self->getSite->getAssets;
}

sub dump {
    my ($self) = @_;

    my $data = [$self->dumpAssets];

    my $format = $self->{__options}->{output_format};
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
    my ($self) = @_;

    my $logger = $self->{__logger};

    #eval { require AnyEvent::Filesys::Notify };
    #if ($@) {
    #    $logger->error($@);
    #    $logger->fatal(__("You have to install AnyEvent::Filesys::Notify"
    #                      . " in order to use the watch functionality"));
    #}

    eval {
        # An initial build failure is fatal.
        $self->build;

        my $config = $self->{__config};

        $self->__startHelpers($config->{helpers});

        $logger->debug(__x("waiting for changes in '{dir}'",
                           dir => $config->{srcdir}));
        AnyEvent::Filesys::Notify->new(
            dirs => [$config->{srcdir}],
            interval => $config->{latency},
            parse_events => 1,
            cb => sub { $self->__onFilesysChange(@_) },
            filter => sub { $self->__filesysChangeFilter(@_) },
        );

        AnyEvent::Loop::run;
    };

    $logger->fatal($@) if $@;
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

sub dumpConfig {
    my ($self) = @_;

    # Make a shallow copy so that we unbless the reference.
    my %config = %{$self->config};
    foreach my $key (grep { /^__q_/ } keys %config) {
        delete $config{$key};
    }

    require YAML::XS;
    print YAML::XS::Dump(\%config);

    return $self;
}

sub migrate {
    my ($self) = @_;

    my $from = $self->getOption('from_system');
    die __"The option '--from-system' is mandatory!\n" if empty $from;

    # Check for valid module names.  Yes, you can use an apostrophe as the
    # separator in Perl but not allowing it here is at our discretion.
    die __x("Invalid source system name '{software}'", software => $from)
        unless $from =~ /^[a-z][a-z0-9_]+(?:(?:::|-)[a-z][a-z0-9_]+)*$/i;

    my $module_name = 'Qgoda::Migrator::'  . $from;
    $module_name =~ s/-/::/g;
    $module_name = lc $module_name;
    $module_name = ucfirst $module_name;
    $module_name =~ s/::(.)/'::' . ucfirst $1/ge;

    my $class_name = $module_name;
    $module_name =~ s{::}{/}g;
    $module_name .= '.pm';

    eval {require $module_name};
    if ($@) {
        my $error = $@;
        my $message = __x("Unsupported source system '{software}'!\nTry the"
                          . " additional option '--verbose' for more"
                          . " information!\n",
                          software => $from);
        $message .= $@ if $self->getOption('verbose');
        die $message;
    }

    my $migrator = $class_name->new;
    $migrator->migrate;

    return $self;
}

sub init {
    my ($self, $args, %options) = @_;

    require Qgoda::Init;
    Qgoda::Init->new->init($args, %options);

    return $self;
}

sub _getProcessors {
    my ($self, @names) = @_;

    my $processors = $self->config->{processors};

    my @processors;
    foreach my $module (@names) {
        my $class_name = 'Qgoda::Processor::' . $module;

        if ($self->{__processors}->{$class_name}) {
            push @processors, $self->{__processors}->{$class_name};
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

# FIXME! This should instantiate scanner plug-ins and use them instead.
sub __scan {
    my ($self, $site) = @_;

    my $logger = $self->{__logger};
    my $config = $self->{__config};

    my $outdir = $config->{outdir};
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

    # And the output directory.
    my @outfiles;
    $self->{__outfiles} = \@outfiles;
    $logger->debug(__x("scanning output directory '{outdir}'",
                       outdir => $config->{outdir}));
    File::Find::find(sub {
        if ($_ ne '.' && $_ ne '..') {
            push @outfiles, Cwd::abs_path($_);
        }
    }, $config->{outdir});

    return $self;
}

sub __analyze {
    my ($self, $site) = @_;

    foreach my $analyzer (@{$self->{__analyzers}}) {
        $analyzer->analyze($site);
    }

    return $self;
}

sub __build {
    my ($self, $site) = @_;

    foreach my $builder (@{$self->{__builders}}) {
        $builder->build($site);
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

sub getAnalyzers {
    my ($self) = @_;

    return $self->{__analyzers};
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
        $self->locateAsset($asset, $site);
    }

    return $self;
}

sub locateAsset {
    my ($self, $asset, $site) = @_;

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

sub debugging {
    my ($self) = @_;

    return $self->{__options}->{__verbose};
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

sub __writePOTFile {
    my ($self, $site) = @_;

    my %masters = $site->getMasters;

    my %textdomains = Template::Plugin::Gettext->textdomains;
    
    my $config = $self->config;
    my $logger = $self->logger;
    my $podir = $config->{paths}->{po};
    my $viewdir = $config->{paths}->{views};

    my @orphans = @{$masters{''} || []};
    foreach my $orphan (@orphans) {
        my $site = $self->getSite;
        my $asset = $site->getAssetByRelpath($orphan);
        my $master = $asset->{master};
        $logger->error(__x("'{filename}': master document '{master}'"
                            . " does not exists",
                            filename => $orphan, master => $master));
    }

    if (empty $config->{po}->{textdomain}) {

        my @mdfiles = uniq map { @$_ } values %masters;
        foreach my $path (sort @mdfiles) {
            $logger->warning(__x("'{filename}': 'master' found but"
                                 . " configuration variable 'po.textdomain'"
                                 . " not set",
                                 filename => $path));
        }

        my @viewfiles  = uniq map { keys %$_ } values %textdomains;
        foreach my $template (sort @viewfiles) {
            $logger->warning(__x("{template}: 'Gettext' plug-in used but"
                                 . " configuration variable 'po.textdomain'"
                                 . " not set",
                                 template => $template));
        }
        
        return $self;
    }

    my @mdpotfiles = sort 
        map { File::Spec->abs2rel($_, $podir) } 
        grep { !empty } keys %masters;

    if (@mdpotfiles) {
        my $mdpotfiles = File::Spec->catfile($podir, 'MDPOTFILES');
        write_file $mdpotfiles, join "\n", @mdpotfiles, ''
            or $self->logger->fatal(__x("cannot write '{filename}': {error}",
                                        filename => $mdpotfiles, error => $!));
    }

    my $textdomain = $config->{po}->{textdomain};
    foreach my $other (keys %textdomains) {
        next if $other eq $textdomain;
        my @templates = sort keys %{$textdomains{$other}};
        foreach my $template (@templates) {
            $logger->warning(__x("{template}: Textdomain '{other}'"
                                 . " in 'Gettext' plug-in invocation does not"
                                 . " match '{textdomain}' from configuration"
                                 . " variable 'po.textdomain'",
                                 other => $other, textdomain => $textdomain,
                                 template => File::Spec->catfile($viewdir,
                                                                 $template)));
        }
    }

    my @potfiles = map { keys %$_ } values %textdomains;

    @potfiles = map { File::Spec->abs2rel($_, $podir) } 
                map { File::Spec->catfile($viewdir, $_) } sort @potfiles;
    push @potfiles, File::Spec->catfile(File::Spec->curdir, 'markdown.pot') 
        if @mdpotfiles;

    my $potfiles = File::Spec->catfile($podir, 'POTFILES');
    write_file $potfiles, join "\n", @potfiles, ''
        or $self->logger->fatal(__x("cannot write '{filename}': {error}",
                                    filename => $potfiles, error => $!));

    return $self;
}

1;
