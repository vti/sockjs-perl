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

    $self->_send_staged_messages;

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

    $self->_send_staged_messages;

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

    my $message = 'a' . JSON::encode_json([@_]);

    return $self->syswrite($message);
}

sub syswrite {
    my $self = shift;
    my ($message) = @_;

    if (!$self->is_connected || $self->is_reconnecting) {
        push @{$self->{messages}}, $message;
    }
    else {
        $self->event('syswrite', $message);
    }

    return $self;
}

sub close {
    my $self = shift;
    my ($code, $message) = @_;

    $code = int $code;
    $self->{close_message} = [$code, $message];

    $self->syswrite(qq{c[$code,"$message"]});

    $self->event('close');

    $self->{is_closed} = 1;

    return $self;
}

sub event {
    my $self = shift;
    my $event = shift;

    $self->{"on_$event"}->($self, @_) if exists $self->{"on_$event"};

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

        $self->event('syswrite', $message);
    }

    if ($self->is_closed) {
        my ($code, $message) = @{$self->{close_message}};

        $self->event('syswrite', qq{c[$code,"$message"]});
    }
}

1;
