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

package Qgoda::JavaScript::Environment;

use strict;

use Qgoda::Util qw(empty);
use JavaScript::DukTape::XS;
use Cpanel::JSON::XS qw(decode_json);
use File::Spec;
use File::Basename qw(dirname);
use Locale::TextDomain qw(qgoda);

sub new {
	my ($class, @global_paths) = @_;

	my $self = {
		__global => [@global_paths]
	};

	my $module_resolve = sub {
		my ($module, $path) = @_;

		#warn "require('$module') from '$path'\n";
		return $self->__normalize($self->__moduleResolve($module, $path));
	};

	my $module_load = sub {
		my ($filename) = @_;

		return $self->__moduleLoad($filename);
	}

	bless $self, $class;
}

sub __moduleResolve {
	my ($self, $module, $path) = @_;

	$path = '' if !defined $path;
	$path = '' if $module =~ m{^/};
	$path = dirname $path if '' ne $path;

	if ($module =~ m{^\.{0,2}/}) {
		my $resolved = eval { load_as_file "$path/$module" };
		$@ or return $resolved;
		$resolved = eval { load_as_directory "$path/$module" };
		$@ or return $resolved;
	}

	my $resolved = eval { load_node_modules $module, $path};
	$@ or return $resolved;

	js_error __x("Cannot find module '{module}'!\n", 
				 module => $module);
}

sub __moduleLoad {
	my ($self, $filename) = @_;

	#warn "Loading $filename\n";
	open my $fh, '<', $filename
		or $self->__jsError(__x("error reading '{filename}': {err}\n",
		                        filename => $filename, err => $!));

	my $code = join '', <$fh>;
	if ($filename =~ /\.json$/) {
		$code = 'module.exports = ' . $code;
	}

	return $code;
}

sub __normalize {
	my ($self, $path) = @_;

	my $here = $path =~ s{^./}{};

	# canonpath does string manipulation, but does not remove "..".
	my $ret = File::Spec->canonpath($path);

	# Let's remove ".." by using a regex.
	while ($ret =~ s{
		(^|/)			  # Either the beginning of the string, or a slash, save as $1
		(				  # Followed by one of these:
			[^/]|		  #  * Any one character (except slash, obviously)
			[^./][^/]|	 #  * Two characters where
			[^/][^./]|	 #	they are not ".."
			[^/][^/][^/]+  #  * Three or more characters
		)				  # Followed by:
		/\.\./			 # "/", followed by "../"
		}{$1}x
	) {
		# Repeat this substitution until not possible anymore.
	}

	# Re-adding the trailing slash, if needed.
	if ($path =~ m!/$! && $ret !~ m!/$!) {
		$ret .= '/';
	}

	$ret = './' . $ret if $here;

	return $ret;
}

sub __jsError {
	my ($self, $error) = @_;

	#warn $error;
	die $error;
}

sub __isFile {
	my ($self, $filename) = @_;

	return 1 if -e $filename && !-d $filename;
}

sub __loadAsFile {
	my ($self, $name) = @_;

	my $filename = $name;
	return $filename if is_file $filename;
	$filename = "$name.js";
	return $filename if is_file $filename;
	# FIXME! Try to mark $filename as json.  That's safer than looking
	# at the extender;
	$filename = "$name.json";
	return $filename if is_file $filename;

	die;
}

sub __loadAsIndex {
	my ($self, $name) = @_;

	return "$name/index.js" if is_file "$name/index.js";
	# FIXME! Can we mark the file?
	return "$name/index.json" if is_file "$name/index.json";

	die;
}

sub __loadAsDirectory {
	my ($self, $name) = @_;

	# Load as directory.
	my $package_json = join '/', $name, 'package.json';
	if (is_file $package_json) {
		open my $fh, '<', $package_json
				or die;
		
		my $decoder = Cpanel::JSON::XS->new;
   		my $package = join '', <$fh>;
		$package = $decoder->decode($package);

		my $main = $package->{main};
		$main = '' if !defined $main;
		$main = "$name/$main";
		my $resolved = eval { return load_as_file $main };
		$@ or return $resolved;
		return load_as_index $main;
	}

	return load_as_index $name;
}

sub __nodeModulesPath {
	my ($self, $start) = @_;
	
	$start = '.' if empty $start;
	my @parts = split /\//, $start;
	my $i = -1 + @parts;
	my @dirs;
	while ($i >= 0) {
		if ('node_modules' eq $parts[$i]) {
			--$i;
			next;
		}
		push @dirs, join '/', @parts[0 .. $i], 'node_modules';
		--$i;
	}

	return @dirs;
}

sub __loadNodeModules {
	my ($module, $path) = @_;

	my @dirs = node_modules_path($path);
	foreach my $dir (@dirs) {
		my $resolved = eval { load_as_file "$dir/$module" };
		$@ or return $resolved;
		$resolved = eval { load_as_directory "$dir/$module" };
		$@ or return $resolved;
	}

	die;
}

__END__
open my $fh, '<', 'index.js' or die;
my $code = join '', <$fh>;
my $vm = JavaScript::Duktape::XS->new;
$vm->set(perl_module_resolve => \&module_resolve);
$vm->set(perl_module_load => \&module_load);
my $result = $vm->eval($code);
use Data::Dumper;
warn Dumper $result;
