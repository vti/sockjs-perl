package SockJS::Transport::XHRPolling;

use strict;
use warnings;

use base 'SockJS::Transport::Base';

sub new {
    my $self = shift->SUPER::new(@_);

    push @{$self->{allowed_methods}}, 'POST';

    return $self;
}

sub dispatch_POST {
    my $self = shift;
    my ($env, $conn) = @_;

    return sub {
        my $respond = shift;

        if ($conn->is_connected && !$conn->is_reconnecting) {
            $self->_write($env, $respond,
                'c[2010,"Another connection still open"]');
            return;
        }

        $conn->write_cb(
            sub {
                my $conn = shift;
                my ($message) = @_;

                $self->_write($env, $respond, $message);
                $conn->reconnecting;
            }
        );

        if ($conn->is_closed) {
            $conn->connected;
            $conn->close;
        }
        elsif ($conn->is_connected) {
            $conn->reconnected;
        }
        else {
            $conn->write('o');

            $conn->connected;
        }
    };
}

sub _write {
    my $self = shift;
    my ($env, $respond, $message) = @_;

    $message .= "\n";

    my @headers;
    if (my $headers = $env->{HTTP_ACCESS_CONTROL_REQUEST_HEADERS}) {
        push @headers, 'Access-Control-Allow-Headers', $headers;
    }

    $respond->(
        [
            200,
            [
                'Content-Type' => 'application/javascript; charset=UTF-8',
                'Access-Control-Allow-Origin'      => '*',
                'Access-Control-Allow-Credentials' => 'true',
                'Cache-Control' =>
                  'no-store, no-cache, must-revalidate, max-age=0',
                @headers
            ],
            [$message]
        ]
    );
}

1;
