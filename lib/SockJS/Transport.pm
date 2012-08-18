package SockJS::Transport;

use strict;
use warnings;

#use SockJS::Transport::XHR;
use SockJS::Transport::WebSocket;

sub build {
    my $self = shift;
    my ($path) = @_;

    if ($path eq 'xhr') {
        return SockJS::Transport::XHR->new;
    }
    elsif ($path eq 'websocket') {
        return SockJS::Transport::WebSocket->new;
    }

    return;
}

1;
