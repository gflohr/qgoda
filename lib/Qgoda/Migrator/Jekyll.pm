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

package Qgoda::Migrator::Jekyll;

use strict;

use Locale::TextDomain qw(com.cantanea.qgoda);
use YAML::XS;
use File::Find;

use Qgoda;
use Qgoda::Util qw(empty read_file yaml_error);
use Qgoda::Migrator::Jekyll::LiquidConverter;

use base qw(Qgoda::Migrator);

sub migrate {
	my ($self) = @_;
	
	my $qgoda = Qgoda->new;
	
	my $config = $self->readConfig;
	
	my $src_dir = $config->{source};
	$src_dir = '.' if empty $config->{source};
	$self->{_src_dir} = $src_dir;
	
	my $out_dir = $qgoda->getOption('output_directory');
	$out_dir = '_migrated' if empty $out_dir;
	$self->{_out_dir} = $out_dir;
	
    my $layouts_dir = delete $config->{layouts_dir};
    $layouts_dir = '_layouts' if empty $layouts_dir;
    $self->{__layouts_dir} = $layouts_dir;

	$self->createOutputDirectory;
	
	my $new_config = $self->{_config} = $self->migrateConfig($config);
	
	$self->migrateLayouts;
	
	$self->writeConfig($new_config);
	
	return $self;
}

sub migrateLayouts {
	my ($self) = @_;
	
	my $in_dir = $self->{__layouts_dir};
	my $out_dir = $self->outputDirectory;
	
    my $logger = $self->logger;
    $logger->info(__x("Migrating Jekyll layouts from '{from_dir}' to "
                      . "Qgoda views in '{to_dir}'.\n",
                      from_dir => $in_dir, to_dir => $out_dir));
    
    my $view_dir = '_views';
    while (-e File::Spec->catfile($out_dir, $view_dir)) {
    	$view_dir .= 'X';
    	$self->{_config}->{directory}->{views} = $view_dir;
    }
    $view_dir = File::Spec->catfile($out_dir, $view_dir);
    
    $self->createDirectory($view_dir);
    
    my $wanted = sub {
    	return if -d $_;
    	
    	my $relpath = File::Spec->abs2rel($File::Find::name, $in_dir);
    	my $outpath = File::Spec->catfile($view_dir, $relpath);
    	
    	$logger->debug("  '$File::Find::name' => '$outpath'");
    	
    };
    File::Find::find($wanted, $in_dir);
    
    return $self;
}

sub migrateConfig {
	my ($self, $config) = @_;
	
    $self->migrateDefaults($config);
    
    # Variables which currently do not exist in qgoda.  This is actually a
    # todo list for qgoda.
    # FIXME! "source" is supported but is called "srcdir".  But it is not
    # enough to just change the key.  We also have to make sure that it
    # not only exists.  We need a method like translateConfigVariable() for
    # that.
    foreach my $variable (qw(source destination safe keep_files timezone
                             encoding show_drafts future lsi
                             limit_posts incremental profile
                             port host baseurl detach webrick
                             no_fenced_code_blocks smart markdown
                             plugins_dir data_dir includes_dir
                             collections markdown_ext unpublished whitelist
                             gems highlighter excerpt_separator 
                             show_dir_listing permalink paginate_path
                             quiet verbose liquid rdiscount redcarpet
                             kramdown error_mode)) {
    	if (exists $config->{$variable}) {
    		$self->logError(__x("The configuration variable '{varname}'"
    		                    . " from '_config.yaml' is not supported or"
    		                    . " by Qgoda or it does not make sense.",
    		                    varname => $variable));
    	}
    }
	
	# JEKYLL_ENV = production
	
	return $config;
}

sub migrateDefaults {
	my ($self, $config) = @_;
	
	my $logger = $self->logger;
	$logger->debug(__"Migrating defaults.");
	
	my $old_defaults = $config->{defaults} or return $self;

    eval {
        my %defaults;
        foreach my $default (@$old_defaults) {
        	my $scope = $default->{scope} or next;
        	my $values = $default->{values} or next;
        	if (!exists $scope->{path}) {
        		my $dump = YAML::XS::Dump($scope);
        		$dump =~ s/^/    /gm;
        		$dump .= "    ---\n";
        		$self->logError(__x("Cannot migrate default without path:\n"
        		                    . "{dump}", dump => $dump));
        	    next;
        	}
        	my $path = $scope->{path};
            my $new = {
            	values => {},
            };
            
            foreach my $key (keys %$values) {
            	my ($name, $value) = $self->translateVariable($key, 
            	                                              $values->{$key});
            	$new->{values}->{$name} = $value;
            }
            
            $defaults{$path} = $new;
        }
        
        $config->{defaults} = \%defaults;
    };
    if ($@) {
    	$self->logError($@);
    }
    
	return $self;
}

sub readConfig {
	my ($self) = @_;
	
	my $logger = $self->logger;
	my $filename = '_config.yml';
    $logger->info(__x("reading configuration from '{filename}'",
                          filename => $filename));
	
	my $yaml = read_file $filename;
    if (!defined $yaml) {
        $logger->fatal(__x("error reading file '{filename}': {error}",
                           filename => $filename, error => $!));
    }
    my $config = eval { YAML::XS::Load($yaml) };
	$logger->fatal(yaml_error $filename, $@) if $@;
	
	return $config;
}

sub translateVariable {
	my ($self, $variable, $value) = @_;
	
	my %value_mapping = (
	    type => {
	    	posts => 'post',
	    },
	);
    my (%name_mapping) = (
        lang => 'lingua',
    );
    	
	if (exists $value_mapping{$variable} 
	    && exists $value_mapping{$variable}->{$value}) {
		$value = $value_mapping{$variable}->{$value};
	}
	
	if (exists $name_mapping{$variable}) {
		$variable = $name_mapping{$variable};
	}
	
	return $variable, $value;
}

1;
