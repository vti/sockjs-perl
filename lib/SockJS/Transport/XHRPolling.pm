package SockJS::Transport::XHRPolling;

use strict;
use warnings;

use SockJS::Exception;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub dispatch {
    my $self = shift;
    my ($env, $session, $path) = @_;

    if ($env->{REQUEST_METHOD} eq 'OPTIONS') {
        my $origin       = $env->{HTTP_ORIGIN};
        my @cors_headers = (
            'Access-Control-Allow-Origin' => !$origin
              || $origin eq 'null' ? '*' : $origin,
            'Access-Control-Allow-Credentials' => 'true'
        );

        return [
            204,
            [   'Expires'                      => '31536000',
                'Cache-Control'                => 'public;max-age=31536000',
                'Access-Control-Allow-Methods' => 'OPTIONS, POST',
                'Access-Control-Max-Age'       => '31536000',
                @cors_headers
            ],
            ['']
        ];
    }

    return [400, ['Content-Length' => 11], ['Bad request']]
      unless $env->{REQUEST_METHOD} eq 'POST';

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
                'Content-Length' => length($message),
                'Access-Control-Allow-Origin'      => '*',
                'Access-Control-Allow-Credentials' => 'true',
                @headers
            ],
            [$message]
        ]
    );
}

1;
