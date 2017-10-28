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
    my $logger = Qgoda->new->logger('config');
    
    my $filename;
    if (!empty $args{filename}) {
        $filename = $args{filename};
    } elsif (-e '_config.yaml') {
        $filename = '_config.yaml';
    } elsif (-e '_config.yml') {
        $filename = '_config.yml';
    } else {
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

    my $self = bless $config, $class;

    eval { $self->checkConfig($self) };
    if ($@) {
        $logger->fatal(__x("{filename}: {error}",
                           filename => $filename, error => $@));
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

    my $viewdir = File::Spec->abs2rel($self->{directories}->{views});
    push @exclude_watch, '!' . quotestar $viewdir
        if $viewdir !~ m{^\.\./};
    my $includedir = File::Spec->abs2rel($self->{directories}->{includes});
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
    	directories => {
    		views => '_views',
            includes => '_includes'
    	},
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
                Markdown => [],
                TT2 => {}
            },
    	},
    	taxonomies => {
    		type => undef,
    		lingua => undef,
    		name => undef,
    		tags => {
    			simweight => 2,
    		},
    		categories => {
    			simweight => 3,
    		},
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
    die __x("'{variable}' must be a list", variable => 'exclude')
        if exists $self->{exclude} && !$self->__isArray($self->{exclude});
    die __x("'{variable}' must be a list", variable => 'exclude_watch')
        if exists $self->{exclude_watch} && !$self->__isArray($self->{exclude_watch});
    die __x("'{variable}' must be a dictionary", variable => 'defaults')
        if exists $self->{defaults} && !$self->__isHash($config->{defaults});
    
    if (exists $self->{defaults}) {
    	my $cursor = delete $self->{defaults};
    	$self->{defaults} = {};
    	$self->__copyDefaults($self->{defaults}, $cursor);
    }
    
    die __x("'{variable}' must be a dictionary", variable => 'taxonomies')
        if exists $self->{taxonomies} && !$self->__isHash($config->{taxonomies});
    foreach my $taxonomy (keys %{$config->{taxonomies}}) {
    	my $record = $config->{taxonomies}->{$taxonomy};
    	if (defined $record) {
            die __x("'{variable}' must be a dictionary", 
                    variable => "taxonomies.$taxonomy")
                unless $self->__isHash($config->{taxonomies}->{$taxonomy});
    		my $simweight = $record->{simweight};
    		if (defined $simweight) {
    			die __x("'{variable}' must be a number greater than or equal to zero",
    			        variable => "taxonomies.$taxonomy.simweight")
    			    unless $self->__isNumber($simweight) && $simweight >= 0;
    		}
    	}
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

sub __copyDefaults {
    my ($self, $config, $cursor, $base) = @_;

    $base = '' if !defined $base;

    while (my ($dir, $rec) = each %$cursor) {
        next if !defined $dir;
        $dir =~ s{^/+}{};
        $dir =~ s{/+$}{};
        $dir =~ s{//+}{/}g;

        my $path = $base . '/' . $dir;
        if (exists $rec->{values}) {
            if (!$self->__isHash($rec->{values})) {
                die __x("defaults: values for '{path}' must be hash",
                        path => $path);
            }

            $config->{$path} ||= {};
            while (my ($key, $value) = each %{$rec->{values}}) {
                $config->{$path}->{$key} = $value;
            }
        }
        if (exists $rec->{subdirs}) {
            if (!ref $rec->{subdirs} || 'HASH' ne ref $rec->{subdirs}) {
                die __x("defaults: subdirs for '{path}' must be hash",
                        path => $path);
            }
            $self->__copyDefaults($config, $rec->{subdirs}, $path);
        }
    }
}

1;
