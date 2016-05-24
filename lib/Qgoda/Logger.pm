#! /bin/false

package Qgoda::Logger;

use strict;

use POSIX qw (setlocale LC_TIME strftime);
use Time::HiRes qw(gettimeofday);

sub new {
    my ($class, %args) = @_;

    my $self = {
        __debug => $args{debug},
        __quiet => $args{quiet},
        __prefix => $args{prefix},
        __client => $args{client},
        __logfile => $args{logfile},
        __reqid => $args{reqid},
    };

    bless $self, $class;
}

sub __logFunc {
    my ($self, $type, @msg) = @_;
    
    my $msg = $self->__makeMessage($type, @msg);

    print $msg;
    
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
    $pre .= ' ';
    
    my @chomped = map { $pre . $_ } 
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
