package Qgoda::AnyEvent::Notify::Backend::KQueue;

# ABSTRACT: Use IO::KQueue to watch for changed files

use strict;

use AnyEvent;
use IO::KQueue;
use Carp;

# Arbitrary limit on open filehandles before issuing a warning
our $WARN_FILEHANDLE_LIMIT = 50;

use base qw(Qgoda::AnyEvent::Notify);

sub _init {
    my $self = shift;

    my $kqueue = IO::KQueue->new()
      or croak "Unable to create new IO::KQueue object";
    $self->_fs_monitor($kqueue);

    # Need to add all the subdirs to the watch list, this will catch
    # modifications to files too.
    my $old_fs = $self->_old_fs;
    my @paths  = keys %$old_fs;

    # Add each file and each directory to a hash of path => fh
    my $fhs = {};
    for my $path (@paths) {
        my $fh = $self->_watch($path);
        $fhs->{$path} = $fh if defined $fh;
    }

    # Now use AE to watch the KQueue
    my $w;
    $w = AE::io $$kqueue, 0, sub {
        if (my @events = $kqueue->kevent) {
            $self->_process_events(@events);
        }
    };
    $self->_watcher({ fhs => $fhs, w => $w });

    $self->_check_filehandle_count;
    return 1;
}

# Need to add newly created items (directories and files) or remove deleted
# items.  This isn't going to be perfect. If the path is not canonical then we
# won't deleted it.  This is done after filtering. So entire dirs can be
# ignored efficiently.
sub _post_process_events {
    my ($self, @events) = @_;

    for my $event (@events) {
        if ($event->is_created) {
            my $fh = $self->_watch($event->path);
            $self->_watcher->{fhs}->{ $event->path } = $fh if defined $fh;
        } elsif ($event->is_deleted) {
            delete $self->_watcher->{fhs}->{ $event->path };
        }
    }

    $self->_check_filehandle_count;
    return;
}

sub _watch {
    my ($self, $path) = @_;

    open my $fh, '<', $path or do {
        warn
          "KQueue requires a filehandle for each watched file and directory.\n"
          . "You have exceeded the number of filehandles permitted by the OS.\n"
          if $! =~ /^Too many open files/;
        return if $! =~ /no such file or directory/i;
        croak "Can't open file ($path): $!";
    };

    $self->_fs_monitor->EV_SET(
        fileno($fh),
        EVFILT_VNODE,
        EV_ADD | EV_ENABLE | EV_CLEAR,
        NOTE_DELETE | NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB | NOTE_LINK |
          NOTE_RENAME | NOTE_REVOKE,
   );

    return $fh;
}

sub _check_filehandle_count {
    my ($self) = @_;

    my $count = $self->_watcher_count;
    carp "KQueue requires a filehandle for each watched file and directory.\n"
      . "You currently have $count filehandles for this Qgoda::AnyEvent::Notify object.\n"
      . "The use of the KQueue backend is not recommended."
      if $count > $WARN_FILEHANDLE_LIMIT;

    return $count;
}

sub _watcher_count {
    my ($self) = @_;
    my $fhs = $self->_watcher->{fhs};
    return scalar keys %$fhs;
}

1;
