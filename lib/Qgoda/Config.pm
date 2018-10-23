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

package Qgoda::Config;

use strict;

use Locale::TextDomain qw('qgoda');
use File::Spec;
use Cwd;
use Scalar::Util qw(reftype looks_like_number);
use File::Globstar qw(quotestar);
use File::Globstar::ListMatch;
use boolean;
use Qgoda::Util qw(read_file empty yaml_error merge_data lowercase 
                   safe_yaml_load);

my %processors;

sub new {
    my ($class, %args) = @_;

    require Qgoda;
    my $q = Qgoda->new;
    my $logger = $q->logger('config');

    my $filename;
    if (!empty $args{filename}) {
        $filename = $args{filename};
    } elsif (-e '_config.yaml') {
        $filename = '_config.yaml';
    } elsif (-e '_config.yml') {
        $filename = '_config.yml';
    } elsif (-e '_config.json') {
        $filename = '_config.json';
    } elsif (!$q->getOption('no-config')) {
        $logger->warning(__"config file '_config.yaml' not found, "
                           . "proceeding with defaults.");
    }

    my $config = $class->default;

    if (!empty $filename) {
        $logger->info(__x("reading configuration from '{filename}'",
                          filename => $filename));
        my $yaml = read_file $filename;
        if (!defined $yaml) {
            $logger->fatal(__x("cannot read '{filename}': {error}",
                               filename => $filename, error => $!));
        }

        my $local = eval { safe_yaml_load $yaml };
        $logger->fatal(yaml_error $filename, $@) if $@;

        foreach my $key (grep { /^__q_/ } keys %{$local || {}}) {
            $logger->fatal(__x("illegal configuration variable '{var}':"
                               . " names starting with '__q_' are reserved"
                               . " for internal purposes.",
                               var => $key));
        }

        $config = merge_data $config, $local if $local;
    }

    my $local_filename;
    if (-e '_localconfig.yaml') {
        $local_filename = '_localconfig.yaml';
    } elsif (-e '_localconfig.yml') {
        $local_filename = '_localconfig.yml';
    } elsif (-e '_localconfig.json') {
        $local_filename = '_localconfig.json';
    }
    if (!empty $local_filename) {
        $logger->info(__x("reading local configuration from '{filename}'",
                          filename => $local_filename));
        my $yaml = read_file $local_filename;
        if (!defined $yaml) {
            $logger->fatal(__x("cannot read '{filename}': {error}",
                               filename => $local_filename, error => $!));
        }

        my $local = eval { safe_yaml_load $yaml };
        $logger->fatal(yaml_error $local_filename, $@) if $@;

        foreach my $key (grep { /^__q_/ } keys %{$local || {}}) {
            $logger->fatal(__x("illegal configuration variable '{var}':"
                               . " names starting with '__q_' are reserved"
                               . " for internal purposes.",
                               var => $key));
        }

        $config = merge_data $config, $local if $local;
    }

    my $self = bless $config, $class;

    eval { $self->checkConfig($self, $args{raw}) };
    if ($@) {
        $logger->fatal(__x("{filename}: {error}",
                           filename => $filename, error => $@));
    }

    # Clean up certain variables or overwrite them unconditionally.
    $config->{srcdir} = Cwd::abs_path($config->{srcdir});
    $config->{paths}->{site} = Cwd::abs_path($config->{paths}->{site});

    my @exclude = (
        '/_*',
        '.*'
    );
    my @exclude_watch = (
        '/_*',
        '.*',
    );

    my $viewdir = File::Spec->abs2rel($self->{paths}->{views});
    push @exclude_watch, '!' . quotestar $viewdir
        if $viewdir !~ m{^\.\./};
    my $includedir = File::Spec->abs2rel($self->{paths}->{includes});
    push @exclude_watch, '!' . quotestar $includedir
        if $includedir !~ m{^\.\./};

    my @config_exclude = @{$config->{exclude} || []};
    my @config_exclude_watch = @{$config->{'exclude-watch'} || $config->{exclude} || []};

    push @exclude, @config_exclude;
    push @exclude_watch, @config_exclude_watch;

    my $outdir = File::Spec->abs2rel($self->{outdir}, $self->{srcdir});
    if ($outdir !~ m{^\.\./}) {
        push @exclude, quotestar $outdir, 1;
        push @exclude_watch, quotestar $outdir, 1;
    }
    $self->{__q_exclude} = File::Globstar::ListMatch->new(
        \@exclude,
        ignoreCase => !$self->{'case-sensitive'}
    );
    $self->{__q_exclude_watch} = File::Globstar::ListMatch->new(
        \@exclude_watch,
        ignoreCase => !$self->{'case-sensitive'}
    );

    return $self;
}

sub default {
    # Default configuration.
    return {
        title => __"A New Qgoda Powered Site",
        generator => "Qgoda $Qgoda::VERSION (http://www.qgoda.net/)",
        # FIXME! This should not be configurable.
        srcdir => '.',
        location => '/{directory}/{basename}/{index}{suffix}',
        permalink => '{significant-path}',
        index => 'index',
        'case-sensitive' => false,
        view => 'default.html',
        latency => 0.5,
        exclude => [],
        exclude_watch => [],
        'no-scm' => [],
        paths => {
            views => '_views',
            plugins => '_plugins',
            po => '_po',
            site => '_site',
            timestamp => '_timestamp',
        },
        'compare-output' => true,
        helpers => {},
        processors => {
            chains => {
                markdown => {
                    modules => [qw(TT2 Strip Markdown)],
                    suffix => 'html',
                    wrapper => 'html'
                },
                html => {
                    modules => [qw(TT2 Strip HTMLFilter)],
                },
                xml => {
                    modules => [qw(TT2 Strip)]
                }
            },
            triggers => {
                md => 'markdown',
                mdown => 'markdown',
                mkdn => 'markdown',
                mdwn => 'markdown',
                mkd => 'markdown',
                html => 'html',
                htm => 'html',
                xml => 'xml',
            },
            options => {
                Markdown => {},
                TT2 => {},
                HTMLFilter => [
                    'AnchorTarget',
                    'Generator',
                    'CleanUp',
                    ['TOC', 
                     content_tag => 'qgoda-content',
                     toc_tag => 'qgoda-toc',
                     start => 2,
                     end => 6,
                     template => 'components/toc.html'
                    ],
                ]
            },
        },
        link_score => 5,
        taxonomies => {
            tags => 2,
            categories => 3,
            links => 1,
        },
        po => {
            tt2 => [qw(_views)],
            'copyright-holder' => __"Set config.po.copyright-holder in _config.yaml",
            'msgid-bugs-address' => __"Set config.po.msgid-bugs-address in _config.yaml",
            qgoda => 'qgoda',
            refresh => 0,
            xgettext => 'xgettext',
            'xgettext-tt2' => 'xgettext-tt2',
            msgfmt => 'msgfmt',
            msgmerge => 'msgmerge',
        },
        'front-matter-placeholder' => {
            '*' => "[% '' %]\n"
        },
    };
}

# Consistency check.
sub checkConfig {
    my ($self, $config, $raw) = @_;

    die __"invalid format (not a hash)\n"
        unless ($self->__isHash($config));
    die __x("'{variable}' must be a dictionary", variable => 'processors')
        unless $self->__isHash($config->{processors});
    die __x("'{variable}' must be a dictionary", variable => 'processors.chains')
        unless $self->__isHash($config->{processors}->{chains});
    foreach my $chain (keys %{$config->{processors}->{chains}}) {
        die __x("'{variable}' must be a dictionary", variable => "processors.chains.$chain")
            unless $self->__isHash($config->{processors}->{chains}->{$chain});
        if (exists $config->{processors}->{chains}->{$chain}->{modules}) {
            die __x("'{variable}' must not be a dictionary", variable => "processors.chains.$chain.modules")
                if $self->__isHash($config->{processors}->{chains}->{$chain}->{modules});
            if (!$self->__isArray($config->{processors}->{chains}->{$chain}->{modules})) {
                $config->{processors}->{chains}->{$chain}->{modules} =
                    [$config->{processors}->{chains}->{$chain}->{modules}],
            }
        } else {
            $config->{processors}->{chains}->{$chain}->{modules} = ['Null'];
        };
        if (exists $config->{processors}->{chains}->{$chain}->{suffix}) {
            die __x("'{variable}' must be a single value", variable => "processors.chains.$chain.suffix")
                if ref $config->{processors}->{chains}->{$chain}->{suffix};
        }
    }
    die __x("'{variable}' must be a dictionary", variable => 'processors.triggers')
        unless $self->__isHash($config->{processors}->{triggers});
    foreach my $suffix (keys %{$config->{processors}->{triggers}}) {
        my $chain = $config->{processors}->{triggers}->{$suffix};
        die __x("processor chain suffix '{suffix}' references undefined chain '{chain}'",
                suffix => $suffix, chain => $chain)
            unless exists $config->{processors}->{chains}->{$chain};
    }
    die __x("'{variable}' must be a dictionary", variable => 'processors.options')
        unless $self->__isHash($config->{processors}->{options});
    die __x("'{variable}' must be a dictionary", variable => 'helpers')
        if exists $self->{helpers} && !$self->__isHash($self->{helpers});
    foreach my $helper (keys %{$config->{helpers}}) {
        my $arguments = $config->{helpers}->{$helper};
        if (empty $arguments) {
            $arguments = [] if empty $arguments;
        } elsif (ref $arguments) {
            die __x("'{variable}' must be a list", variable => "helpers.$helper")
                if !$self->__isArray($arguments);
        } else {
            $arguments = [$arguments];
        }
        $config->{helpers}->{$helper} = $arguments;
    }
    die __x("'{variable}' must be a list", variable => 'exclude')
        if exists $self->{exclude} && !$self->__isArray($self->{exclude});
    die __x("'{variable}' must be a list", variable => 'exclude_watch')
        if exists $self->{exclude_watch} && !$self->__isArray($self->{exclude_watch});
    die __x("'{variable}' must be a list", variable => 'defaults')
        if exists $self->{defaults} && !$self->__isArray($config->{defaults});

    die __x("'{variable}' must be a dictionary", variable => 'taxonomies')
        if exists $self->{taxonomies} && !$self->__isHash($config->{taxonomies});
    foreach my $taxonomy (keys %{$config->{taxonomies}}) {
        $config->{taxonomies}->{$taxonomy} = 1
            if !defined $config->{taxonomies}->{$taxonomy};
    }

    die __x("'{variable}' must be a single value", variable => 'type')
        if ref $config->{type};

    die __x("'{variable}' must be a dictionary", variable => 'po')
        if exists $self->{po} && !$self->__isHash($config->{po});
    foreach my $cmd (qw(xgettext xgettext_tt2 qgoda msgfmt msgmerge)) {
        if (exists $config->{po}->{$cmd}) {
            die __x("'{variable}' must not be empty", variable => "po.$cmd")
                if empty $config->{po}->{$cmd};
            if (ref $config->{po}->{$cmd} 
                && !$self->__isArray($config->{po}->{$cmd})) {
                die __x("'{variable}' must be a single value or a a list", 
                        variable => "po.$cmd");
            }
        }
    }

    die __x("'{variable}' must be a list", variable => 'linguas')
        if exists $config->{linguas} && !$self->__isArray($config->{linguas});
    die __x("'{variable}' must be a list", variable => 'analyzers')
        if exists $self->{analyzers} && !$self->__isArray($self->{analyzers});
    die __x("'{variable}' must be a list", variable => 'po.mdextra')
        if exists $self->{po}->{mdextra} && !$self->__isArray($self->{po}->{mdextra});
    die __x("'{variable}' must be a list", variable => 'po.views')
        if exists $self->{po}->{views} && !$self->__isArray($self->{po}->{views});
    die __x("'{variable}' must be a list", variable => 'no-scm')
        if exists $self->{'no-scm'} && !$self->__isArray($self->{'no-scm'});

    # Has to be done after everything was read. We need the value of
    # case-sensitive.
    $self->{defaults} = $self->__compileDefaults($self->{defaults})
        unless $raw;

    return $self;
}

sub ignorePath {
    my ($self, $path, $watch) = @_;

    # We only care about regular files and directories.  Symbolic links are
    # excluded on purpose.  If, however, the file is deleted, we have to
    # do the normal checks.
    if (-e $path && (!-f $path && !-d $path)) {
        return $self;
    }

    # Do not ignore the top-level directory.  This check is needed because
    # abs2rel() returns a lone dot for it.
    return if $path eq $self->{srcdir};

    my $relpath = File::Spec->abs2rel($path, $self->{srcdir});

    if ($watch) {
        return $self if $self->{__q_exclude_watch}->match($relpath);
    } else {
        return $self if $self->{__q_exclude}->match($relpath);
    }
    return;
}

sub __isHash {
    my ($self, $what) = @_;

    return unless $what && ref $what && 'HASH' eq reftype $what;

    return $self;
}

sub __isArray {
    my ($self, $what) = @_;

    return unless $what && ref $what && 'ARRAY' eq reftype $what;

    return $self;
}

sub __isNumber {
    my ($self, $what) = @_;

    return unless defined $what;

    return $self if looks_like_number $what;

    return $self;
}

sub __compileDefaults {
    my ($self, $rules) = @_;

    my @defaults;
    foreach my $rule (@$rules) {
        my $pattern = $rule->{files};
        $pattern = '*' if empty $pattern;

        if (ref $pattern) {
            if (!$self->__isArray($pattern)) {
                die __x("'{variable}' must be a scalar or a list",
                        variable => 'defaults.files');
            }
        } else {
            $pattern = [$pattern];
        }

        $pattern = File::Globstar::ListMatch->new($pattern,
                                                  !$self->{'case-sensitive'});
        if (exists $rule->{values}) {
            if (!$self->__isHash($rule->{values})) {
                die __x("'{variable}' must be a hash",
                        variable => 'defaults.values');
            }
        }

        push @defaults, [$pattern, $rule->{values} || {}];
    }

    return \@defaults;
}

1;
