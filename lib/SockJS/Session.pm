package SockJS::Session;

use strict;
use warnings;

use JSON;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{messages} = [];

    return $self;
}

sub set {
    my $self = shift;
    my ($key, $value) = @_;

    $self->{custom}->{$key} = $value;

    return $self;
}

sub get {
    my $self = shift;
    my ($key) = @_;

    return $self->{custom}->{$key};
}

sub type { $_[0]->{type} }

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

sub closed {
    my $self = shift;

    $self->{is_connected} = 0;
    $self->{is_closed}    = 1;

    $self->event('close');

    return $self;
}

sub aborted {
    my $self = shift;

    if (exists $self->{on_abort}) {
        $self->event('abort');
    }
    else {
        $self->event('close');
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

    my $message = 'a' . JSON::encode_json([@_]);

    return $self->syswrite($message);
}

sub syswrite {
    my $self = shift;
    my ($message) = @_;

    if (($self->is_connected || $self->is_closed)
        && !$self->is_reconnecting)
    {
        $self->event('syswrite', $message);
    }
    else {
        push @{$self->{messages}}, $message;
    }

    return $self;
}

sub close {
    my $self = shift;
    my ($code, $message) = @_;

    $self->{close_message} ||= do {
        $code    ||= 3000;
        $message ||= 'Get away!';

        [int $code, $message];
    };

    $self->syswrite('c['
          . $self->{close_message}->[0] . ',"'
          . $self->{close_message}->[1]
          . '"]');

    $self->closed;

    return $self;
}

sub event {
    my $self  = shift;
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
}

1;
