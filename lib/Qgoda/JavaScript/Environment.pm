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
use JavaScript::Duktape::XS;
use Cpanel::JSON::XS qw(decode_json);
use File::Spec;
use File::Basename qw(dirname);
use Locale::TextDomain qw(qgoda);

sub new {
	my ($class, %args) = @_;

	my $global = $args{global};
	$global = [$global] if defined $global;
	my @global = @{$global || []};
	my $exchange = empty $args{exchange} ? '__perl__' : $args{exchange};

	my $self = {
		__global => [@global],
		__exchange_name => $exchange,
	};

	my $module_resolve = sub {
		my ($module, $path) = @_;

		#warn "require('$module') from '$path'\n";
		return $self->__normalize($self->__moduleResolve($module, $path));
	};

	my $module_load = sub {
		my ($filename) = @_;

		#warn "Loading $filename\n";
		return $self->__moduleLoad($filename);
	};

	# Our exchange buffer with the JavaScript world.
	my $perl = {
		output => {}
	};

	$self->{__vm} = JavaScript::Duktape::XS->new(
		{
			save_messages => $args{no_output}
		}
	);
	$self->{__vm}->set(perl_module_resolve => $module_resolve);
	$self->{__vm}->set(perl_module_load => $module_load);

	my $no_console = $args{'no_console'};
	$self->{__jsout} = '';
	$self->{__jserr} - '';
	$self->{__no_output} = $args{'no_output'};

	unless ($no_console) {
		$perl->{modules}->{console} = {
			log => sub {
				if ($args{no_output}) {
					$self->{__jsout} .= shift . "\n";
				} else {
					print shift . "\n";
				}
			},
			error => sub {
				if ($args{no_output}) {
					$self->{__jserr} .= shift . "\n";
				} else {
					print STDERR shift . "\n";
				}
			},
			warn => sub {
				if ($args{no_output}) {
					$self->{__jserr} .= shift . "\n";
				} else {
					print STDERR shift . "\n";
				}
			}
		};

		$self->{__vm}->set(console => {});
	}

	# All code that wants to call back into Perl must run after thie line.
	$self->{__vm}->set($exchange, $perl);
	$self->{__exchange} = $perl;

	unless ($no_console) {
		require 'Qgoda/JavaScript/console.js';
		$self->{__vm}->eval(Qgoda::JavaScript::console->code);
	}

	bless $self, $class;
}

sub exchange {
	my ($self, $key, $value) = @_;

	my $exchange = $self->{__vm}->get($self->{__exchange_name}) or return;

	if (@_ > 2) {
		$exchange->{$key} = $value;
		$self->{__vm}->set($self->{__exchange_name}, $exchange);
	}
	
	return $exchange->{$key};
}

sub run {
	my ($self, $code) = @_;

	if ($self->{__no_output}) {
		my $q = Qgoda->new;
		$self->{__jsout} = '';
		$self->{__jserr} = '';
		$self->{__vm}->reset_msgs;
	}
	
	my $retval = $self->{__vm}->eval($code);

	if ($self->{__no_output}) {
		my $stdout = $self->{__jsout};
		$stdout = '' if empty $stdout;
		my $vm_stdout = $self->{__vm}->get_msgs->{stdout};
		$vm_stdout = '' if empty $vm_stdout;

		my $stderr = $self->{__jserr};
		$stderr = '' if empty $stderr;
		my $vm_stderr = $self->{__vm}->get_msgs->{stderr};
		$vm_stderr = '' if empty $vm_stderr;

		my $q = Qgoda->new;
		$q->jsout($stdout . $vm_stdout);
		$q->jserr($stderr . $vm_stderr);
	}

	return $retval;
}

sub vm {
	shift->{__vm};
}

sub __moduleResolve {
	my ($self, $module, $path) = @_;

	# FIXME! Do we have to implement a cache or does Duktape do that for us?
	$path = '' if !defined $path;
	$path = '' if $module =~ m{^/};
	$path = dirname $path if '' ne $path;

	if ($module =~ m{^\.{0,2}/}) {
		my $resolved = eval { $self->__loadAsFile("$path/$module") };
		$@ or return $resolved;
		$resolved = eval { $self->__loadAsDirectory("$path/$module") };
		$@ or return $resolved;
	}

	my $resolved = eval { $self->__loadNodeModules($module, $path) };
	$@ or return $resolved;

	$self->__jsError(__x("Cannot find module '{module}'!\n",
	                     module => $module));
}

sub __moduleLoad {
	my ($self, $filename) = @_;

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
	return $filename if $self->__isFile($filename);
	$filename = "$name.js";
	return $filename if $self->__isFile($filename);
	# FIXME! Try to mark $filename as json.  That's safer than looking
	# at the extender;
	$filename = "$name.json";
	return $filename if $self->__isFile($filename);

	die;
}

sub __loadAsIndex {
	my ($self, $name) = @_;

	return "$name/index.js" if $self->__isFile("$name/index.js");
	return "$name/index.json" if $self->__isFile("$name/index.json");

	die;
}

sub __loadAsDirectory {
	my ($self, $name) = @_;

	# Load as directory.
	my $package_json = join '/', $name, 'package.json';
	if ($self->__isFile($package_json)) {
		open my $fh, '<', $package_json
				or die;
		
		my $decoder = Cpanel::JSON::XS->new;
   		my $package = join '', <$fh>;
		$package = $decoder->decode($package);

		my $main = $package->{main};
		$main = '' if !defined $main;
		$main = "$name/$main";
		my $resolved = eval { $self->__loadAsFile($main) };
		$@ or return $resolved;
		return $self->__loadAsIndex($main);
	}

	return $self->__loadAsIndex($name);
}

sub __nodeModulesPath {
	my ($self, $start) = @_;
	
	$start = '.' if empty $start;
	my @parts = split /\//, $start;
	my $i = -1 + @parts;
	my @dirs = @{$self->{__global}};
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
	my ($self, $module, $path) = @_;

	my @dirs = $self->__nodeModulesPath($path);
	foreach my $dir (@dirs) {
		my $resolved = eval { $self->__loadAsFile("$dir/$module") };
		$@ or return $resolved;
		$resolved = eval { $self->__loadAsDirectory("$dir/$module") };
		$@ or return $resolved;
	}

	die;
}

1;
