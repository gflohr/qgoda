package Qgoda::AnyEvent::Notify::Backend::FSEvents;

# ABSTRACT: Use Mac::FSEvents to watch for changed files

use strict;

use AnyEvent;
use Mac::FSEvents;
use Carp;

use base qw(Qgoda::AnyEvent::Notify);

sub _init {
    my $self = shift;

    # Created a new Mac::FSEvents fs_monitor for each dir to watch
    # TODO: don't add sub-dirs of a watched dir
    my @fs_monitors =
      map { Mac::FSEvents->new({ path => $_, latency => $self->interval, }) }
      @{ $self->dirs };

    # Create an AnyEvent->io watcher for each fs_monitor
    my @watchers;
    for my $fs_monitor (@fs_monitors) {

        my $w = AE::io $fs_monitor->watch, 0, sub {
            if (my @events = $fs_monitor->read_events) {
                $self->_process_events(@events);
            }
        };
        push @watchers, $w;

    }

    $self->_fs_monitor(\@fs_monitors);
    $self->_watcher(\@watchers);
    return 1;
}

1;
