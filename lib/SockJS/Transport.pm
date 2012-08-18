package SockJS::Transport;

use strict;
use warnings;

use SockJS::Transport::EventSource;
use SockJS::Transport::HtmlFile;
use SockJS::Transport::WebSocket;
use SockJS::Transport::XHRPolling;
use SockJS::Transport::XHRSend;
use SockJS::Transport::XHRStreaming;
use SockJS::Transport::JSONPPolling;
use SockJS::Transport::JSONPSend;

sub build {
    my $self = shift;
    my ($path) = @_;

    if ($path eq 'xhr') {
        return SockJS::Transport::XHRPolling->new;
    }
    elsif ($path eq 'xhr_send') {
        return SockJS::Transport::XHRSend->new;
    }
    elsif ($path eq 'xhr_streaming') {
        return SockJS::Transport::XHRStreaming->new;
    }
    if ($path eq 'jsonp') {
        return SockJS::Transport::JSONPPolling->new;
    }
    elsif ($path eq 'jsonp_send') {
        return SockJS::Transport::JSONPSend->new;
    }
    elsif ($path eq 'websocket') {
        return SockJS::Transport::WebSocket->new;
    }
    elsif ($path eq 'eventsource') {
        return SockJS::Transport::EventSource->new;
    }
    elsif ($path eq 'htmlfile') {
        return SockJS::Transport::HtmlFile->new;
    }

    return;
}

1;
