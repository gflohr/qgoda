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

package Qgoda::Logger;

use strict;

use POSIX qw (setlocale LC_TIME strftime);
use Time::HiRes qw(gettimeofday);
use Term::ANSIColor qw(colored);
use IO::Interactive;

sub new {
    my ($class, %args) = @_;

    my $self = {
        __debug => $args{debug},
        __quiet => $args{quiet},
        __prefix => $args{prefix},
        __client => $args{client},
        __logfile => $args{logfile},
        __reqid => $args{reqid},
        __log_fh => $args{log_fh} || \*STDOUT,
    };

    bless $self, $class;
}

sub __logFunc {
    my ($self, $type, @msg) = @_;

    my $msg = $self->__makeMessage($type, @msg);

    $self->{__log_fh}->print($msg);

    return 1;
}

sub __makeMessage {
    my ($self, $type, @msgs) = @_;

    my $prefix = $self->{__prefix};
    $prefix = '' unless $prefix;

    my ($whole, $trailing) = split(/[^0-9]/, scalar gettimeofday());
    $trailing ||= '';
    $trailing .= length($trailing) < 5
               ? '0' x (5 - length($trailing))
               : '';

    my $timefmt = "\%a \%b \%d \%H:\%M:\%S.$trailing \%Y";

    my $saved_locale = setlocale LC_TIME;
    setlocale LC_TIME, 'POSIX';
    my $timestamp = strftime $timefmt, localtime;
    setlocale LC_TIME, $saved_locale;

    my $client = $self->{__client} || '';
    $client = "client $client" if $client;

    my $reqid = $self->{__reqid} || '';

    my $pre = join '',
              map { "[$_]" }
              grep { $_ } $timestamp, $reqid, $client, $type, $prefix;
    $pre .= ' ' unless $msgs[0] =~ /^\[/;;

    my $colored = sub { $_[0] };

    if (IO::Interactive::is_interactive()) {
        my %colors = (
            error => 'bold bright_red',
            warning => 'red',
            info => 'blue',
            fatal => 'bold red',
        );
        if (exists $colors{$type}) {
            $colored = sub { colored([$colors{$type}], $_[0]) };
        }
    }

    my @chomped = map { $pre . $colored->($_) }
                  grep { $_ ne '' }
                  map { $self->__trim($_) } @msgs;

    my $msg = join "\n", @chomped, '';

    return $msg;
}

sub info {
    my ($self, @msgs) = @_;
    return if $self->{__quiet};

    $self->__logFunc(info => @msgs);

    return 1;
}

sub debug {
    my ($self, @msgs) = @_;
    return unless $self->{__debug};

    $self->__logFunc(debug => @msgs);

    return 1;
}

sub error {
    my ($self, @msgs) = @_;

    $self->__logFunc (error => @msgs);

    return 1;
}

sub warning {
    my ($self, @msgs) = @_;

    return if $self->{__quiet};

    $self->__logFunc (warning => @msgs);

    return 1;
}

sub safeWarning {
    my ($self, @msgs) = @_;

    # Print them even in quite mode.

    # And now escape them for logging in vim style.
    foreach my $msg (@msgs) {
        chomp $msg;
        $msg =~ s{([\x00-\x1f^])}{
            if ('^' eq $1) {
                '^^';
            } else {
                '^' . chr (ord($1) + ord('@'));
            }
        }gexs;
    }

    $self->__logFunc(warning => @msgs);

    return 1;
}

sub fatal {
    my ($self, @msgs) = @_;

    $self->__logFunc (fatal => @msgs);

    exit 1;
}

sub __trim {
    my ($self, $line) = @_;
    return '' unless defined $line;
    $line =~ s/\s+$//mg;
    return split /\n/, $line;
}

sub client {
    my ($self, $client) = @_;

    $self->{__client} = $client if defined $client;

    return $self->{__client};
}

1;
