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

package Qgoda::Config;

use strict;

use Locale::TextDomain qw('com.cantanea.qgoda');
use File::Spec;
use YAML::XS;
use Cwd;
use Scalar::Util qw(reftype looks_like_number);
use File::Globstar qw(quotestar);
use File::Globstar::ListMatch;

use Qgoda::Util qw(read_file empty yaml_error merge_data lowercase);

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
            $logger->fatal(__x("error reading file '{filename}': {error}",
                               filename => $filename, error => $!));
        }

        my $local = eval { YAML::XS::Load($yaml) };
        $logger->fatal(yaml_error $filename, $@) if $@;

        foreach my $key (grep { /^__q_/ } keys %{$local || {}}) {
            $logger->fatal(__x("illegal configuration variable '{var}':"
                               . " names starting with '__q_' are reserved"
                               . " for internal purposes.",
                               var => $key));
        }

        $config = merge_data $config, $local if $local;
    }

    if (-e '_localconfig.yaml') {
        $filename = '_localconfig.yaml';
    } elsif (-e '_localconfig.yml') {
        $filename = '_localconfig.yml';
    } elsif (-e '_localconfig.json') {
        $filename = '_localconfig.json';
    } else {
        undef $filename;
    }
    if (!empty $filename) {
        $logger->info(__x("reading local configuration from '{filename}'",
                          filename => $filename));
        my $yaml = read_file $filename;
        if (!defined $yaml) {
            $logger->fatal(__x("error reading file '{filename}': {error}",
                               filename => $filename, error => $!));
        }

        my $local = eval { YAML::XS::Load($yaml) };
        $logger->fatal(yaml_error $filename, $@) if $@;

        foreach my $key (grep { /^__q_/ } keys %{$local || {}}) {
            $logger->fatal(__x("illegal configuration variable '{var}':"
                               . " names starting with '__q_' are reserved"
                               . " for internal purposes.",
                               var => $key));
        }

        $config = merge_data $config, $local if $local;
    }

    my $self = bless $config, $class;

    eval { $self->checkConfig($self) };
    if ($@) {
        $logger->fatal(__x("{filename}: {error}",
                           filename => $filename, error => $@));
    }

    if (-e '_localconfig.yaml') {
        $filename = 'localconfig.yaml';
    } elsif (-e 'localconfig.yml') {
        $filename = 'localconfig.yml';
    } else {
        undef $filename;
    }

    # Fill in defaults and consistency checks.
    $config->{outdir} = File::Spec->catpath($config->{srcdir}, '_site')
        if empty $config->{outdir};

    # Clean up certain variables or overwrite them unconditionally.
    $config->{srcdir} = Cwd::abs_path($config->{srcdir});
    $config->{outdir} = Cwd::abs_path($config->{outdir});

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
    my @config_exclude_watch = @{$config->{exclude_watch} || $config->{exclude} || []};

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
        type => 'page',
        srcdir => '.',
        location => '/{directory}/{basename}/{index}{suffix}',
        permalink => '{significant-path}',
        index => 'index',
        'case-sensitive' => 0,
        view => 'default.html',
        latency => 0.5,
        exclude => [],
        exclude_watch => [],
        paths => {
            views => '_views',
            includes => '_includes'
        },
        helpers => {},
        processors => {
            chains => {
                markdown => {
                    modules => [qw(TT2 Markdown)],
                    suffix => 'html',
                    wrapper => 'html'
                },
                html => {
                    modules => 'TT2',
                },
            },
            triggers => {
                md => 'markdown',
                mdown => 'markdown',
                mkdn => 'markdown',
                mdwn => 'markdown',
                mkd => 'markdown',
                html => 'html',
                htm => 'html',
            },
            options => {
                Markdown => {},
                TT2 => {}
            },
        },
        taxonomies => {
            tags => 2,
            categories => 3,
        },
        po => {
            xgettext => {
                tt2 => [qw(_views _includes)],
            }
        },
    };
}

# Consistency check.
sub checkConfig {
    my ($self, $config) = @_;

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
    die __x("'{variable}' must be a dictionary", variable => 'po.xgettext')
        if exists $self->{po}->{xgettext}
        && !$self->__isHash($config->{po}->{xgettext});
    foreach my $xgettext (keys %{$config->{po}->{xgettext} || {}}) {

    }

    # Has to be done after everything was read. We need the value of
    # case-sensitive.
    $self->{defaults} = $self->__compileDefaults($self->{defaults});

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
                die __"'defaults.files' must be a scalar or a list";
            }
        } else {
            $pattern = [$pattern];
        }

        $pattern = File::Globstar::ListMatch->new($pattern,
                                                  $self->{'case-insensitive'});
        if (exists $rule->{values}) {
            if (!$self->__isHash($rule->{values})) {
                die __"defaults.values must be a hash";
            }
        }

        push @defaults, [$pattern, $rule->{values} || {}];
    }

    return \@defaults;
}

1;
