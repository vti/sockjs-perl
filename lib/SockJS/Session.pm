package SockJS::Session;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub is_connected {
    my $self = shift;

    return $self->{is_connected};
}

sub connected {
    my $self = shift;

    $self->{is_connected} = 1;

    $self->event('connected');

    return $self;
}

sub reconnecting {
    my $self = shift;

    $self->{is_reconnecting} = 1;

    return $self;
}

sub is_reconnecting {
    my $self = shift;

    return $self->{is_reconnecting};
}

sub reconnected {
    my $self = shift;

    $self->{is_reconnecting} = 0;

    if (@{$self->{messages}}) {
        my $messages = [];
        while (my $message = shift @{$self->{messages}}) {
            push @$messages, $message;
        }
        $self->event('write', @$messages);
    }

    return $self;
}

sub is_closed {
    my $self = shift;

    return $self->{is_closed};
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

    if ($self->{on_write}) {
        $self->event('write', @_);
    }
    else {
        push @{$self->{messages}}, $message;
    }

    return $self;
}

sub close {
    my $self = shift;

    $self->{close_message} = [@_];

    $self->event('close', @_);

    $self->{is_closed} = 1;

    return $self;
}

sub close_message {
    my $self = shift;

    return $self->{close_message};
}

sub event {
    my $self = shift;
    my $event = shift;

    $self->{"on_$event"}->($self, @_) if exists $self->{"on_$event"};

    return $self;
}

1;
