package SockJS::Connection;

use strict;
use warnings;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{type}     = $params{type}     || '';
    $self->{close_cb} = $params{close_cb} || sub { };
    $self->{write_cb} = $params{write_cb} || sub { };

    $self->{messages} = [];

    return $self;
}

sub type { $_[0]->{type} }

sub write_cb {
    my $self = shift;

    if (@_) {
        $self->{write_cb} = $_[0];
    }

    return $self->{write_cb};
}

sub close_cb {
    my $self = shift;

    if (@_) {
        $self->{close_cb} = $_[0];
    }

    return $self->{close_cb};
}

sub is_connected {
    my $self = shift;

    return $self->{is_connected};
}

sub connected {
    my $self = shift;

    $self->{is_connected}    = 1;
    $self->{is_reconnecting} = 0;
    $self->{is_closed}       = 0;

    $self->_send_staged_messages;

    $self->fire_event('connect');

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

    $self->_send_staged_messages;

    return $self;
}

sub closed {
    my $self = shift;

    return if $self->is_closed;

    $self->{is_connected} = 0;
    $self->{is_closed}    = 1;

    $self->fire_event('close');

    return $self;
}

sub aborted {
    my $self = shift;

    return if $self->is_closed;

    $self->{is_connected} = 0;
    $self->{is_closed}    = 1;

    if (exists $self->{on_abort}) {
        $self->fire_event('abort');
    }
    else {
        $self->fire_event('close');
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

    push @{$self->{"on_$event"}}, $cb;

    return $self;
}

sub write {
    my $self = shift;
    my ($message) = @_;

    return $self unless defined $message && $message ne '';

    if (($self->is_connected || $self->is_closed)
        && !$self->is_reconnecting)
    {
        $self->{write_cb}->($self, $message);
    }
    else {
        push @{$self->{messages}}, $message;
    }

    return $self;
}

sub close {
    my $self = shift;
    my ($code, $message) = @_;

    if ($self->type ne 'raw_websocket') {
        $self->{close_message} ||= do {
            $code    ||= 3000;
            $message ||= 'Get away!';

            [int $code, $message];
        };

        $self->write('c['
              . $self->{close_message}->[0] . ',"'
              . $self->{close_message}->[1]
              . '"]');
    }

    $self->{close_cb}->($self);

    $self->closed;

    return $self;
}

sub fire_event {
    my $self  = shift;
    my $event = shift;

    if (exists $self->{"on_$event"}) {
        foreach my $ev (@{$self->{"on_$event"}}) {
            $ev->($self, @_);
        }
    }

    return $self;
}

sub _send_staged_messages {
    my $self = shift;

    while ($self->is_connected
        && !$self->is_reconnecting
        && @{$self->{messages}})
    {
        my $message = shift @{$self->{messages}};
        my $type = substr($message, 0, 1);

        if ($type eq 'a') {
            while ($self->{messages}->[0]
                && substr($self->{messages}->[0], 0, 1) eq $type)
            {
                my $next_message = shift @{$self->{messages}};

                $next_message =~ s{^a\[}{};
                $message      =~ s{\]}{,$next_message};
            }
        }

        $self->{write_cb}->($self, $message);
    }
}

1;
