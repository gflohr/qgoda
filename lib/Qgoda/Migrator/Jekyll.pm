#! /bin/false

# Copyright (C) 2016-2023 Guido Flohr <guido.flohr@cantanea.com>,
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

#VERSION

use Locale::TextDomain qw('qgoda');
use YAML;

use Qgoda::Util qw(safe_yaml_load merge_data read_file);

use base qw(Qgoda::Migrator);

use constant DEFAULT_CONFIGURATION => <<'EOF';
# Where things are
source              : .
destination         : ./_site
collections_dir     : .
plugins_dir         : _plugins # takes an array of strings and loads plugins in that order
layouts_dir         : _layouts
data_dir            : _data
includes_dir        : _includes
sass:
  sass_dir: _sass
collections:
  posts:
    output          : true

# Handling Reading
safe                : false
include             : [".htaccess"]
exclude             : ["Gemfile", "Gemfile.lock", "node_modules", "vendor/bundle/", "vendor/cache/", "vendor/gems/", "vendor/ruby/"]
keep_files          : [".git", ".svn"]
encoding            : "utf-8"
markdown_ext        : "markdown,mkdown,mkdn,mkd,md"
strict_front_matter : false

# Filtering Content
show_drafts         : null
limit_posts         : 0
future              : false
unpublished         : false

# Plugins
whitelist           : []
plugins             : []

# Conversion
markdown            : kramdown
highlighter         : rouge
lsi                 : false
excerpt_separator   : "\n\n"
incremental         : false

# Serving
detach              : false
port                : 4000
host                : 127.0.0.1
baseurl             : "" # does not include hostname
show_dir_listing    : false

# Outputting
permalink           : date
paginate_path       : /page:num
timezone            : null

quiet               : false
verbose             : false
defaults            : []

liquid:
  error_mode        : warn
  strict_filters    : false
  strict_variables  : false

# Markdown Processors
kramdown:
  auto_ids          : true
  entity_output     : as_char
  toc_levels        : [1, 2, 3, 4, 5, 6]
  smart_quotes      : lsquo,rsquo,ldquo,rdquo
  input             : GFM
  hard_wrap         : false
  footnote_nr       : 1
  show_warnings     : false
EOF


sub settings {
	return (
		config => __"location of Jekyll config file (default '_config.yml')",
	);
}

sub run {
	my ($self) = @_;

	my $logger = $self->logger;

	$logger->info('starting migration');

	$self->__migrateConfig;

	return $self;
}

sub __migrateConfig {
	my ($self) = @_;

	my $logger = $self->logger;

	my $config = YAML::Load(DEFAULT_CONFIGURATION);

	my $config_files = $self->options->{settings}->{config};
	if (!defined $config_files) {
		$config_files = '_config.yml' if !defined $config_files;
		$config_files = '_config.yaml' if !-e $config_files;
	}
	my @config_files = split /[ \t]*,[ \t]/, $config_files;
	foreach my $config_file (@config_files) {
		$logger->debug(
			__x("reading configuration from {filename}",
			    filename => $config_file
		));

		my $yaml = read_file $config_file
			or $logger->fatal(__x("error reading '{filename}': {error}",
			                      filename => $config_file, error => $!));
		my $file_config = safe_yaml_load $yaml
			or $logger->fatal(__x("error reading '{filename}': {error}"));
		$config = merge_data $config, $file_config;
	}

	$self->writeConfig;

	return $self;
}

use constant CONFIG_ACTIONS => {
	source => { call => '__migrateConfigSource' },
	destination => { set => 'path.site'},
};

sub __migrateConfigSection {
	my ($self, $config, $prefix) = @_;

	$prefix .= '.' if defined $prefix;
	my $default_action = {
		call => '__migrateUnhandledConfigVariable',
	};
	foreach my $variable (keys %$config) {
		my $full_variable = "$prefix$variable";
		my $action = CONFIG_ACTIONS->{$full_variable} || $default_action;
		if ($action->{call}) {
			my $method = $action->{call};
			$self->$method($variable, $full_variable, $config);
		} elsif ($action->{set}) {

		}
	}

	return $self;
}

1;
