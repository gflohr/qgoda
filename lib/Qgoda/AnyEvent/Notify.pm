package Qgoda::AnyEvent::Notify;

use AnyEvent;
use Path::Iterator::Rule;
use Cwd qw/abs_path/;
use Qgoda::AnyEvent::Notify::Event;
use Carp;
use Locale::TextDomain qw(qgoda);

use Qgoda::Util qw(empty perl_class class2module);

sub new {
	my ($class, %args) = @_;

	my $self = {
		map { '__' . $_ => $args{$_} } keys %args
	};

	bless $self, $class;
	$self->_old_fs($self->_scan_fs($self->dirs));

	$self->__applyBackend;
	$self->_init;

	return $self;
}

sub dirs {
	my ($self) = @_;

	return $self->{__dirs};
}

sub cb {
	my ($self, $cb) = @_;

	$self->{__cb} = $cb if @_ > 1;

	return $self->{__cb};
}

sub interval {
	my ($self) = @_;

	return $self->{__interval};
}

sub no_external {
	my ($self) = @_;

	return $self->{__no_external};
}

sub backend {
	my ($self) = @_;

	return $self->{__backend};
}

sub filter {
	my ($self, $filter) = @_;

	$self->{__filter} = $filter if @_ > 1;

	return $self->{__filter};
}

sub parse_events {
	my ($self, $parse_events) = @_;

	$self->{__parse_events} = $parse_events if @_ > 1;

	return $self->{__parse_events};
}

sub skip_subdirs {
	my ($self, $skip_subdirs) = @_;

	$self->{__skip_subdirs} = $skip_subdirs if @_ > 1;

	return $self->{__skip_subdirs};
}

sub _fs_monitor {
	my ($self, $fs_monitor) = @_;

	$self->{__fs_monitor} = $fs_monitor if @_ > 1;

	return $self->{__fs_monitor};
}

sub _old_fs {
	my ($self, $old_fs) = @_;

	$self->{__old_fs} = $old_fs if @_ > 1;

	return $self->{__old_fs};
}

sub _watcher {
	my ($self, $watcher) = @_;

	$self->{__watcher} = $watcher if @_ > 1;

	return $self->{__watcher};
}

sub _process_events {
	my ($self, @raw_events) = @_;

	# Some implementations provided enough information to parse the raw events,
	# other require rescanning the file system (ie, Mac::FSEvents).
	# The original behavior was to rescan in all implementations, so we
	# have added a flag to avoid breaking old code.

	my @events;

	if ($self->parse_events and $self->can('_parse_events')) {
		@events =
		  $self->_parse_events(sub { $self->_apply_filter(@_) }, @raw_events);
	} else {
		my $new_fs = $self->_scan_fs($self->dirs);
		@events =
		  $self->_apply_filter($self->_diff_fs($self->_old_fs, $new_fs));
		$self->_old_fs($new_fs);

		# Some backends (when not using parse_events) need to add files
		# (KQueue) or directories (Inotify2) to the watch list after they are
		# created. Give them a chance to do that here.
		$self->_post_process_events(@events)
		  if $self->can('_post_process_events');
	}

	$self->cb->(@events) if @events;

	return \@events;
}

sub _apply_filter {
	my ($self, @events) = @_;

	if (ref $self->filter eq 'CODE') {
		my $cb = $self->filter;
		@events = grep { $cb->($_->path) } @events;
	} elsif (ref $self->filter eq 'Regexp') {
		my $re = $self->filter;
		@events = grep { $_->path =~ $re } @events;
	}

	return @events;
}

# Return a hash ref representing all the files and stats in @path.
# Keys are absolute path and values are path/mtime/size/is_dir
# Takes either array or arrayref
sub _scan_fs {
	my ($self, @args) = @_;

	# Accept either an array of dirs or a array ref of dirs
	my @paths = ref $args[0] eq 'ARRAY' ? @{ $args[0] } : @args;

	my $fs_stats = {};

	my $rule = Path::Iterator::Rule->new;
	$rule->skip_subdirs(qr/./)
		if (ref $self) =~ /^Qgoda::AnyEvent::Notify/
		&& $self->skip_subdirs;
	my $next = $rule->iter(@paths);
	while (my $file = $next->()) {
		my $stat = $self->_stat($file)
		  or next; # Skip files that we can't stat (ie, broken symlinks on ext4)
		$fs_stats->{ abs_path($file) } = $stat;
	}

	return $fs_stats;
}

sub _diff_fs {
	my ($self, $old_fs, $new_fs) = @_;
	my @events = ();

	for my $path (keys %$old_fs) {
		if (not exists $new_fs->{$path}) {
			push @events,
			  Qgoda::AnyEvent::Notify::Event->new(
				path   => $path,
				type   => 'deleted',
				is_dir => $old_fs->{$path}->{is_dir},
			 );
		} elsif (
			$self->_is_path_modified($old_fs->{$path}, $new_fs->{$path}))
		{
			push @events,
			  Qgoda::AnyEvent::Notify::Event->new(
				path   => $path,
				type   => 'modified',
				is_dir => $old_fs->{$path}->{is_dir},
			 );
		}
	}

	for my $path (keys %$new_fs) {
		if (not exists $old_fs->{$path}) {
			push @events,
			  Qgoda::AnyEvent::Notify::Event->new(
				path   => $path,
				type   => 'created',
				is_dir => $new_fs->{$path}->{is_dir},
			 );
		}
	}

	return @events;
}

sub _is_path_modified {
	my ($self, $old_path, $new_path) = @_;

	return 1 if $new_path->{mode} != $old_path->{mode};
	return   if $new_path->{is_dir};
	return 1 if $new_path->{mtime} != $old_path->{mtime};
	return 1 if $new_path->{size} != $old_path->{size};
	return;
}

# Originally taken from Filesys::Notify::Simple --Thanks Miyagawa
sub _stat {
	my ($self, $path) = @_;

	my @stat = stat $path;

	# Return undefined if no stats can be retrieved, as it happens with broken
	# symlinks (at least under ext4).
	return unless @stat;

	return {
		path   => $path,
		mtime  => $stat[9],
		size   => $stat[7],
		mode   => $stat[2],
		is_dir => -d _,
	};
}

sub __applyBackend {
	my $self = shift;

	my $backend;
	if (!empty $self->backend) {
		# Use the Backend prefix unless the backend starts with a +
		my $prefix  = "Qgoda::AnyEvent::Notify::Backend::";
		$backend = $self->backend;
		$backend = $prefix . $backend unless $backend =~ s{^\+}{};
	} elsif ($self->no_external) {
		$backend = "Qgoda::AnyEvent::Notify::Backend::Fallback";
	} elsif ($^O eq 'linux') {
		$backend = "Qgoda::AnyEvent::Notify::Backend::Inotify2";
	} elsif ($^O eq 'darwin') {
		$backend = "Qgoda::AnyEvent::Notify::Backend::FSEvents";
	} elsif ($^O =~ /bsd/) {
		$backend = "Qgoda::AnyEvent::Notify::Backend::KQueue";
	} else {
		$backend = "Qgoda::AnyEvent::Notify::Backend::Fallback";
	}

	if (!perl_class $backend) {
		die __x("Invalid file system backend '{backend}!'\n");
	}

	my $module = class2module $backend;
	eval { require $module };
	if ($@) {
		die __x("Error initializing file system backend '{backend}': {err}.",
		        backend => $backend, err => $@);
	}
	
	bless $self, $backend;
}

1;

=head1 NAME

Qgoda::AnyEvent::Notify - An AnyEvent compatible module to monitor
files/directories for changes

=head1 DESCRIPTION

This is a rewrite of L<Qgoda::AnyEvent::Notify> but without L<Moo>.  The
reason behind this is that the vast majority of Qgoda dependencies were
caused by this single module.
