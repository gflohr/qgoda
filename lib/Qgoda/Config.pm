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
use YAML;
use Cwd;
use Scalar::Util qw(reftype looks_like_number);

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

    # Default configuration.
    my $config = {
    	title => __"A New Qgoda Powered Site",
    	type => 'page',
    	srcdir => '.',
    	location => '/{directory}/{basename}/{index}{suffix}',
    	permalink => '{significant-path}',
    	index => 'index',
    	'case-sensitive' => 0,
    	view => 'default.html',
    	processors => {
            chains => {
                markdown => {
                	modules => [qw(HTML Markdown)],
                	suffix => 'html',
                	wrapper => 'html'
                },
                html => {
                	modules => 'HTML',
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
            modules => {
                Markdown => 'Markdown',
                HTML => 'TT2',
            },
            options => {
                Markdown => [],
                TT2 => {}
            },
    	},
    	taxonomies => {
    		type => undef,
    		linguas => undef,
    		tags => {
    			simweight => 2,
    		},
    		categories => {
    			simweight => 3,
    		},
    	},
    };
    
    if (!empty $filename) {
        $logger->info(__x("reading configuration from '{filename}'",
                          filename => '_config.yaml'));
        my $yaml = read_file $filename;
        if (!defined $yaml) {
        	$logger->fatal(__x("error reading file '{filename}': {error}",
        	                   filename => $filename, error => $!));
        }
        my $local = eval { YAML::Load($yaml) };
        $logger->fatal(yaml_error $filename, $@) if $@;
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
    
    return $self;
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
    die __x("'{variable}' must be a dictionary", variable => 'processors.modules')
        unless $self->__isHash($config->{processors}->{modules});
    foreach my $module (keys %{$config->{processors}->{modules}}) {
        die __x("'{variable}' must be a scalar", variable => "processors.chains.$module")
            if ref $config->{processors}->{modules}->{$module};
        die __x("'{variable}' must not be empty", variable => "processors.chains.$module")
            if empty $config->{processors}->{modules}->{$module};
    }
    die __x("'{variable}' must be a dictionary", variable => 'processors.options')
        unless $self->__isHash($config->{processors}->{options});
    die __x("'{variable}' must be a list", variable => 'exclude')
        if exists $self->{exclude} && !$self->__isArray($self->{exclude});
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

    return $self;
}

sub ignorePath {
    my ($self, $path) = @_;
    
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

    if ($self->{exclude}) {
    	my %excludes = map { $_ => 1 } @{$self->{exclude}};
    	return $self if $excludes{$relpath};
    }
    
    # Ignore all underscore files and directories but only on the top-level
    # except for "_views".
    return $self if '_' eq substr $relpath, 0, 1 && $relpath !~ m{^_views/};
    
    # Ignore all hidden files and directories.
    foreach my $part (File::Spec->splitdir($relpath)) {
        return $self if '.' eq substr $part, 0, 1;
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
        next if !length $dir;

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
