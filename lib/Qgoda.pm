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

package Qgoda;

use strict;

use version;
our $VERSION = 'v0.10.1'; #VERSION

use Qgoda::Util::FileSpec qw(
	absolute_path abs2rel catdir catfile catpath rel2abs splitpath
);

# FIXME! This assumes that we are a top-level package. Instead,
# inpect also __PACKAGE__ and adjust the directory accordingly.
use File::Basename qw(fileparse dirname);
my $package_dir = catdir(absolute_path(dirname __FILE__), 'Qgoda');

use base 'Exporter';
use vars qw(@EXPORT $VERSION);
@EXPORT = qw($VERSION);

use Locale::TextDomain 1.30 qw(qgoda);
use Locale::Messages;
use Locale::gettext_dumb;
use File::Find;
use Scalar::Util qw(reftype blessed);
use AnyEvent;
use AnyEvent::Loop;
use AnyEvent::Handle;
use AnyEvent::Util;
use Symbol qw(gensym);
use IPC::Open3 qw(open3);
use Cwd qw(getcwd);
use Socket;
use IO::Handle;
use POSIX qw(:sys_wait_h setlocale LC_ALL);
use Template::Plugin::Gettext 0.7;
use List::Util 1.45 qw(uniq);
use YAML::XS 0.67;
use AnyEvent::Filesys::Watcher;
use Time::HiRes qw(usleep);
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
use Qgoda::DependencyTracker;
use Qgoda::BuildTask;

my $qgoda;

sub new {
	return $qgoda if $qgoda;

	my ($class, $options, $params) = @_;

	Locale::Messages->select_package('gettext_pp');
	my $locale = setlocale LC_ALL, '';

	$options ||= {};
	$params ||= {};

	my $self = $qgoda = bless {}, $class;

	$self->{__options} = { %$options };
	my $logger = $self->{__logger} = $self->logger;

	$self->{__config} = Qgoda::Config->new unless $params->{no_config};
	$self->{__builders} = [Qgoda::Builder->new];
	$self->{__processors} = {};
	$self->{__load_plugins} = 1;
	$self->{__post_processors} = {};
	$self->{__dep_tracker} = Qgoda::DependencyTracker->new;
	$self->{__locale} = $locale;

	return $qgoda;
}

sub getDependencyTracker {
	shift->{__dep_tracker};
}

sub getLocale {
	shift->{__locale};
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

	$self->__getPostProcessors;

	return $self;
}

sub __initBuildTasks {
	my ($self) = @_;

	my $config = $self->{__config};

	$self->{__preBuildTasks} = [];
	if ($config->{'pre-build'}) {
		foreach my $task (@{$config->{'pre-build'}}) {
			push @{$self->{__preBuildTasks}}, Qgoda::BuildTask->new(
				name => $task->{name},
				run => $task->{run},
			);
		}
	}

	$self->{__postBuildTasks} = [];
	if ($config->{'post-build'}) {
		foreach my $task (@{$config->{'post-build'}}) {
			push @{$self->{__postBuildTasks}}, Qgoda::BuildTask->new(
				name => $task->{name},
				run => $task->{run},
			);
		}
	}
}

sub __runBuildTasks {
	my ($self, $tasks, $prefix) = @_;

	foreach my $task (@$tasks) {
		$self->__runBuildTask($task, $prefix);
	}

	return $self;
}

sub __runBuildTask {
	my ($self, $task, $prefix) = @_;

	my $logger = $self->logger;

	my $helper = $task->name;
	my $log_prefix = "[helper][$helper] ";

	my $safe_helper = $helper;
	$safe_helper =~ s/[^a-z0-9]+/_/;

	my $args = $task->run;
	$args = [$args] if !ref $args;

	my $exec = $ENV{"QGODA_HELPER_$safe_helper"};
	if (defined $exec && $exec ne '') {
		if ($>) {
			$logger->fatal($log_prefix
				. __x("Environment variable '{variable}' ignored when running as root",
					variable => "QGODA_HELPER_$helper"));
		}
		$args->[0] = $exec;
	}

	$logger->info($log_prefix . __x("starting helper: {helper}", helper => $helper));

	my ($pid, $cout, $cerr);
	my $win32process;
	if ($^O eq 'MSWin32') {
		($pid, $cout, $cerr, $win32process) = $self->__spawnHelperWin32($log_prefix, @$args);
	} else {
		($pid, $cout, $cerr) = $self->__spawnHelper($log_prefix, @$args);
	}

	$logger->debug(__x('child process pid {pid}', pid => $pid));

	my $finished_cv;
	$finished_cv = AE::cv;

	my %handles = (1 => 1, 2 => 2);
	my $ahout = AnyEvent::Handle->new(
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
		on_eof => sub {
			delete $handles{1};
			$finished_cv->send if !%handles;
		},
	);

	my $aherr = AnyEvent::Handle->new(
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
		on_eof => sub {
			delete $handles{2};
			$finished_cv->send if !%handles;
		},
	);

	# Wait for the child process to finish.
	$finished_cv->recv;

	return $self;
}

sub build {
	my ($self, %options) = @_;

	$self->initPlugins;
	$self->__initBuildTasks;

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

	my $site = $qgoda->getSite;
	if (!$site) {
		$site = Qgoda::Site->new($config);
		$self->setSite($site);
	}

	$self->scan($site);
	$self->__initVersionControlled($site)
		if !empty $config->{scm} && 'git' eq $config->{scm};

	my $textdomain = $config->{po}->{textdomain};
	my $locale_dir = catfile($config->{srcdir}, 'LocaleData');
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

	$self->__runBuildTasks($self->{__preBuildTasks}, 'pre-build');
	$self->__build($site, %options);
	$self->__runBuildTasks($self->{__postBuildTasks}, 'post-build');

	return $self if $options{dry_run};

	my $deleted = $self->__prune($site);

	my $modified = scalar keys %{$site->getModified};

	if ($modified + $deleted) {
		if (!empty $config->{paths}->{timestamp}) {
			my $timestamp_file = catfile($config->{srcdir},
													$config->{paths}->{timestamp});
			if (!write_file($timestamp_file, sprintf "%d\n", time)) {
					$logger->error(__x("cannot write '{file}': {error}!",
								file => $timestamp_file, error => $!));
			}
		}
	}

	foreach my $module (sort keys %{$self->{__post_processors}}) {
		$logger->debug(__x("[Qgoda::PostProcessor::{module}]: postProcessing", module => $module));
		eval { $self->{__post_processors}->{$module}->postProcess($site) };
		if ($@) {
			$logger->error(__x("[Qgoda::PostProcessor::{module}]: {error}", module => $module, error => $@));
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

sub buildForWatch {
	my ($self, $changeset, $options) = @_;

	if ($changeset && @$changeset) {
		my $site = $self->getSite;
		if (!$site) {
			$site = Qgoda::Site->new;
			$self->setSite($site);
		}
		$self->getDependencyTracker->compute($changeset);
	}

	$self->build(%{$options || {}});

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
		$self->buildForWatch([], \%options);

		my $config = $self->{__config};

		$self->__startHelpers($config->{helpers}) if keys %{$config->{helpers}};

		$self->{__stop} = AnyEvent->condvar;

		$logger->debug(__x("waiting for changes in '{dir}'",
						   dir => $config->{srcdir}));
		my $watcher;
		my %extra;
		if ('MSWin32' eq $^O || 'cygwin' eq $^O) {
			# Filesys::Notify::Win32::ReadDirectoryChanges creates so-called
			# "interpreter" threads for watching the filesystem for changes
			# and they lead to all kinds of spurious errors.
			#
			# Also, either that module or the Duktape binding causes error
			# messages about freeing a non-existing shared string
			# "perl_module_resolver".
			$extra{backend} = 'Fallback';
		}
		$watcher= AnyEvent::Filesys::Watcher->new(
			directories => [$config->{srcdir}],
			interval => $config->{latency},
			callback => sub { $self->__onFilesysChange(\%options, @_) },
			filter => sub { $self->__filesysChangeFilter(@_) },
			%extra
		);

		my $reason = $self->{__stop}->recv;
		$reason = __"no reason given!" if empty $reason;

		$logger->info(__x("terminating on demand: {reason}",
						  reason => $reason));
	};
	my $x = $@;

	$self->__reapChildren('no exit');

	$logger->debug(__"done reaping children");

	$logger->fatal($@) if $x;

	return $self;
}

sub __reapChildren {
	my ($self, $no_exit) = @_;

	$self->{__terminating} = 1;

	my @pids = keys %{$self->{__helpers}} or return;

	my $logger = $self->logger;

	$logger->info(__"terminating child processes");

	foreach my $pid (@pids) {
		my $helper = $self->{__helpers}->{$pid} or next;
		my $name = $helper->{name};
		$logger->debug(
			__x("sending SIGTERM to helper '{helper}' with pid {pid}",
				helper => $name, pid => $pid,
		));
		kill TERM => $pid;
	}

	exit 1 unless $no_exit;

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

	my $logger = $self->logger;

	$self->{__helpers} = {};

	my $sigchld_handler = sub {
		$logger->debug(__"SIGCHLD received");
		my $pid;
		while (1) {
			$pid = waitpid -1, WNOHANG;
			last if $pid <= 0;

			my $helper = delete $self->{__helpers}->{$pid};
			if ($helper) {
				if ($self->{__terminating}) {
					$logger->info(__x"helper '{helper}' with pid {pid} has terminated",
						helper => $helper->{name}, pid => $pid);
				} else {
					$logger->error(__x"helper '{helper}' with pid {pid} has terminated",
						helper => $helper->{name}, pid => $pid);
				}
			} else {
				if ($self->{__terminating}) {
					$logger->info(__x"child process with pid {pid} has terminated",
						helper => $helper->{name}, pid => $pid);
				} else {
					$logger->info(__x"child process with pid {pid} has terminated",
						helper => $helper->{name}, pid => $pid);
				}
			}
		}
	};
	$SIG{CHLD} = $sigchld_handler;

	$SIG{TERM} = $SIG{INT} = $SIG{QUIT} = sub { $self->__reapChildren };

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

	$logger->info($log_prefix . __x("starting helper: {helper}",
									helper => $helper));

	my ($pid, $cout, $cerr);

	if ('MSWin32' eq $^O) {
		($pid, $cout, $cerr) = $self->__spawnHelperWin32($log_prefix, @$args);
	} else {
		($pid, $cout, $cerr) = $self->__spawnHelper($log_prefix, @$args);
	}

	$logger->debug(__x('child process pid {pid}', pid => $pid));

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
		# Ignore.  Otherwise, AnyEvent::Handle throws ugly errors on MS-DOS.
		on_eof => sub {},
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
		# Ignore.  Otherwise, AnyEvent::Handle throws ugly errors on MS-DOS.
		on_eof => sub {},
	);

	return $self;
}

sub __spawnHelper {
	my ($self, $log_prefix, @args) = @_;

	my $cout = gensym;
	my $cerr = gensym;
	my $logger = $self->logger;

	my $pid = open3 undef, $cout, $cerr, @args
		or $logger->fatal($log_prefix . __x("failure starting helper: {error}",
											error => $!));
	return $pid, $cout, $cerr;
}

sub __spawnHelperWin32 {
	my ($self, $log_prefix, @args) = @_;

	# See http://www.guido-flohr.net/platform-independent-asynchronous-child-process-ipc/
	# for an explanation of the code.

	require Win32::Process;

	my $logger = $self->logger;
	my ($rout, $wout) = portable_socketpair
		or $logger->fatal($log_prefix
			. __x("cannot create socket pair: {error}", error => $!));
	my ($rerr, $werr) = portable_socketpair
		or $logger->fatal($log_prefix
			. __x("cannot create socket pair: {error}", error => $!));

	my $true = 1;
	my $FIONBIO = 0x8004667e;
	ioctl $rout, $FIONBIO, \$true
    	or $logger->fatal($log_prefix
			. __x("cannot set helper standard output to non-blocking: {error}",
			      error => $!));
	ioctl $rerr, $FIONBIO, \$true
    	or $logger->fatal($log_prefix
			. __x("cannot set herlp standard error to non-blocking: {error}",
			      error => $!));

	my $saved_log_handle = $logger->logHandle;

	my $command = $self->__makeWin32Command(@args);
	my $image = $self->__findWin32Program(@args);

	open SAVED_OUT, '>&STDOUT'
    	or $logger->fatal($log_prefix
			. __x("cannot save standard output handle: {error}",
			      error => $!));
	if (!$self->getOption('log_stderr')) {
		$logger->logHandle(\*SAVED_OUT);
	}
	open STDOUT, '>&' . $wout->fileno
		or $logger->fatal($log_prefix
			. __x("cannot redirect standard output handle: {error}",
			      error => $!));

	open SAVED_ERR, '>&STDERR'
    	or $logger->fatal($log_prefix
			. __x("cannot save standard output handle: {error}",
			      error => $!));
	if ($self->getOption('log_stderr')) {
		$logger->logHandle(\*SAVED_ERR);
	}
	open STDERR, '>&' . $werr->fileno
		or $logger->fatal($log_prefix
			. __x("cannot redirect standard output handle: {error}",
			      error => $!));

	my $process;
	Win32::Process::Create($process, $image, $command, 0, 0, '.')
    	or $logger->fatal($log_prefix
			. __x("cannot spawn helper process: {command}: {error}",
			      command => $command,
			      error => Win32::FormatMessage(Win32::GetLastError())));
	my $pid = $process->GetProcessID;

	open STDOUT, '>&SAVED_OUT'
		or $logger->fatal($log_prefix
			. __x("cannot restore standard output: {error}", error => $!));
	open STDERR, '>&SAVED_ERR'
		or $logger->fatal($log_prefix
			. __x("cannot restore standard output: {error}", error => $!));

	$logger->logHandle($saved_log_handle);

	return $pid, $rout, $rerr, $process;
}

sub __findWin32Program {
	my ($self, $program) = @_;

	$program =~ s/[ \t].*//;
	if (File::Spec->file_name_is_absolute($program)) {
		return $program;
	} elsif ($program =~ m{[/\\]}) {
		my $here = getcwd;
		return File::Spec->catfile($here, $program);
	}

	foreach my $path (File::Spec->path) {
		my $try = File::Spec->catfile($path, $program);
		if ($try =~ /\.(?:exe|com|bat)$/i) {
			return $try if -e $program;
		} else {
			return "$try.exe" if -e "$try.exe";
			return "$try.com" if -e "$try.com";
			return "$try.bat" if -e "$try.bat";
		}
	}

	# Let the operating system complain.
	return $program;
}

sub __makeWin32Command {
	my ($self, @cmd) = @_;

return join ' ', @cmd;
	foreach my $cmd (@cmd) {
		$cmd =~ s/"/""/g;
		$cmd = qq{"$cmd"} if $cmd =~ /[\001-\040]/;
	}

	return join ' ', @cmd;
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

sub __getPostProcessors {
	my ($self) = @_;

	my $processors = $self->config->{'post-processors'}->{modules};

	foreach my $module (@$processors) {
		my $class_name = 'Qgoda::PostProcessor::' . $module;

		$self->logger->fatal(__x("invalid post-processor name '{processor}'",
									processor => $module))
			if !perl_class $class_name;

		my $module_name = class2module $class_name;

		require $module_name;
		my $options = $self->config->{'post-processors'}->{options};
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

		$self->logger->debug(__x("found post-processor '{module}'", module => $class_name));
		my $processor = $class_name->new(@options);
		$self->{__post_processors}->{$class_name} = $processor;
	}

	return $self;
}

sub scan {
	my ($self, $site, $just_find) = @_;

	my $logger = $self->{__logger};
	my $config = $self->{__config};
	my $srcdir = $config->{srcdir};

	if (!$just_find && $config->{'track-dependencies'}) {
		my $deptracker = $self->getDependencyTracker;
		my $dirty = $deptracker->dirty;
		if ($dirty) {
			$logger->debug(__"skip source directory scan and use dependencies");
			$self->{__outfiles} = $deptracker->outfiles;
			foreach my $relpath (@$dirty) {
				my $path = rel2abs($relpath, $config->{srcdir});
				my $asset = Qgoda::Asset->new($path, $relpath);
				$site->addDirtyAsset($asset);
			}

			return $self;
		}
	} else {
		$site->reset;
		$site->{artefacts} = {};
	}

	my $outdir = $config->{paths}->{site};

	# Scan the source directory.
	$logger->debug(__x("scanning source directory '{srcdir}'",
					   srcdir => $config->{srcdir}));
	File::Find::find({
		# FIXME! This must be configurable.  It should also be configurable
		# whether follow_fast or follow_skip should be used.
		follow => 1,
		wanted => sub {
			if (-f $_) {
				my $path = absolute_path($_);
				if (!$config->ignorePath($path)) {
					my $relpath = abs2rel($path, $config->{srcdir});
					my $asset = Qgoda::Asset->new($path, $relpath);
					$site->addAsset($asset);
				}
			}
		},
		preprocess => sub {
			# Prevent descending into ignored directories.
			my $path = absolute_path($File::Find::dir);
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
			push @outfiles, absolute_path($_);
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

	my $outdir = $self->config->{paths}->{site};
	my $matcher = $self->config->{__q_precious};
	my $deleted = 0;
	foreach my $outfile (@outfiles) {
		my $reloutfile = abs2rel $outfile, $outdir;
		if ($matcher->match($reloutfile)) {
			$logger->debug(__x("not pruning precious file '{outfile}'",
			                   outfile => $outfile));
		} elsif ($directories{$outfile} || $site->getArtefact($outfile)) {
			# Mark the containing directory as generated.
			my ($volume, $directory, $filename) = splitpath $outfile;
			my $container = catpath $volume, $directory, '';
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

	$logger->debug(__"pruning done");

	return $deleted;
}

sub __filesysChangeFilter {
	my ($self, $event) = @_;

	my $path = $event->path;

	# It would be possible to also ignore deleted directories but that is
	# not very relevant for Qgoda's typical usage.
	return 1 if $event->isDirectory;

	my $config = $self->{__config};

	if ($path =~ m{/_stop$} && -e $path) {
		my $srcdir = $config->{paths}->{srcdir};
		my $relpath = abs2rel($path, $srcdir);
		if ('_stop' eq $relpath) {
			my $reason = read_file $path;
			unlink $path;
			$self->stop(trim $reason);
		}
		return;
	}

	if ($config->ignorePath($path, 1)) {
		my $logger = $self->{__logger};
		$logger->debug(__x("changed file '{filename}' is ignored",
						   filename => $path));
		return;
	}

	return $self;
}

sub __onFilesysChange {
	my ($self, $options, @events) = @_;

	my @files;

	my $logger = $self->{__logger};
	my $config = $self->{__config};

	foreach my $event (@events) {
		$logger->info(__x("file '{filename}' has changed",
						  filename => $event->path));
		push @files, $event->path;
	}

	return if !@files;

	$logger->info(__"start rebuilding site because of file system change");

	if ($config->{'track-dependencies'}) {
		eval { $self->buildForWatch(\@events, $options) };
	} else {
		eval { $self->build(%$options) };
	}
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
		my $abspath = rel2abs($relpath, $srcdir);
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
										   ignoreCase => $config->{'case-insensitive'});
}

sub versionControlled {
	my ($self, $path, $is_absolute) = @_;

	my $config = $self->config;
	return $self if !$config->{scm} || 'git' ne $config->{scm};

	$self->__initVersionControlled if !$self->{__version_controlled};

	my $key = $is_absolute ? 'absolute' : 'relative';
	return $self if $self->{__version_controlled}->{$key}->{$path};

	my $no_scm = $self->__initNoSCMPatterns or return;

	$path = rel2abs($path, $self->config->{srcdir});
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
