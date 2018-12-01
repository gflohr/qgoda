package Qgoda::AnyEvent::Notify::Backend::Fallback;

# ABSTRACT: Fallback method of file watching (check in regular intervals)

use strict;

use AnyEvent;
use Carp;

use base qw(Qgoda::AnyEvent::Notify);

sub _init {
    my $self = shift;

    $self->_watcher(
        AnyEvent->timer(
            after    => $self->interval,
            interval => $self->interval,
            cb       => sub {
                $self->_process_events();
            })) or croak "Error creating timer: $@";

    return 1;
}

1;
