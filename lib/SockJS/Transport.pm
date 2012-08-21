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
    my $path = shift;

    my $class;

    if ($path eq 'xhr') {
        $class = 'XHRPolling';
    }
    elsif ($path eq 'xhr_send') {
        $class = 'XHRSend';
    }
    elsif ($path eq 'xhr_streaming') {
        $class = 'XHRStreaming';
    }
    if ($path eq 'jsonp') {
        $class = 'JSONPPolling';
    }
    elsif ($path eq 'jsonp_send') {
        $class = 'JSONPSend';
    }
    elsif ($path eq 'websocket') {
        $class = 'WebSocket';
    }
    elsif ($path eq 'eventsource') {
        $class = 'EventSource';
    }
    elsif ($path eq 'htmlfile') {
        $class = 'HtmlFile';
    }

    return unless $class;

    $class = "SockJS::Transport::$class";

    return $class->new(name => $path, @_);
}

1;
