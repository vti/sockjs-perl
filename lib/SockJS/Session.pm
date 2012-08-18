package SockJS::Session;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub on {
    my $self = shift;
    my ($event, $cb) = @_;

    $self->{"on_$event"} = $cb;

    return $self;
}

sub write {
    my $self = shift;
    my ($message) = @_;

    $self->event('write', @_);

    return $self;
}

sub close {
    my $self = shift;

    $self->event('close', @_);

    return $self;
}

sub event {
    my $self = shift;
    my $event = shift;

    $self->{"on_$event"}->($self, @_) if exists $self->{"on_$event"};

    return $self;
}

1;
