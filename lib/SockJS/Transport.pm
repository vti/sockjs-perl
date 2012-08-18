package SockJS::Transport;

use strict;
use warnings;

use SockJS::Transport::XHR;
use SockJS::Transport::WebSocket;
use SockJS::Transport::EventSource;

sub build {
    my $self = shift;
    my ($path) = @_;

    if ($path eq 'xhr' || $path eq 'xhr_send' || $path eq 'xhr_streaming') {
        return SockJS::Transport::XHR->new;
    }
    elsif ($path eq 'websocket') {
        return SockJS::Transport::WebSocket->new;
    }
    elsif ($path eq 'eventsource') {
        return SockJS::Transport::EventSource->new;
    }

    return;
}

1;
