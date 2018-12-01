package Qgoda::AnyEvent::Notify::Event;

# ABSTRACT: Object to report changes in the monitored filesystem

use strict;

sub new {
	my ($class, %args) = @_;

	my $self = {
		map { '__' . $_ => $args{$_} } keys %args
	};

	bless $self, $class;
}

sub path {
	my ($self) = @_;

	return $self->{__path};
}

sub type {
	my ($self) = @_;

	return $self->{__type};
}

sub is_dir {
	my ($self) = @_;

	return $self->{__is_dir};
}

sub is_created {
    return shift->type eq 'created';
}
sub is_modified {
    return shift->type eq 'modified';
}
sub is_deleted {
    return shift->type eq 'deleted';
}

1;
