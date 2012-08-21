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
    my ($env, $session, $path) = @_;

    return sub {
        my $respond = shift;

        if ($session->is_connected && !$session->is_reconnecting) {
            $self->_write($env, $session, $respond, 'c[2010,"Another connection still open"]');
            return;
        }

        $session->on(
            syswrite => sub {
                my $session = shift;
                my ($message) = @_;

                $self->_write($env, $session, $respond, $message);
                $session->reconnecting;
            }
        );

        if ($session->is_closed) {
            $session->connected;
            $session->close;
        }
        elsif ($session->is_connected) {
            $session->reconnected;
        }
        else {
            $session->syswrite('o');

            $session->connected;
        }
    };
}

sub _write {
    my $self = shift;
    my ($env, $session, $respond, $message) = @_;

    $message .= "\n";

    my @headers;
    if (my $headers = $env->{HTTP_ACCESS_CONTROL_REQUEST_HEADERS}) {
        push @headers, 'Access-Control-Allow-Headers', $headers;
    }

    $respond->(
        [   200,
            [   'Content-Type'   => 'application/javascript; charset=UTF-8',
                'Access-Control-Allow-Origin'      => '*',
                'Access-Control-Allow-Credentials' => 'true',
                @headers
            ],
            [$message]
        ]
    );
}

1;
