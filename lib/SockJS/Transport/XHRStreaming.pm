package SockJS::Transport::XHRStreaming;

use strict;
use warnings;

use base 'SockJS::Transport::Base';

sub new {
    my $self = shift->SUPER::new(@_);
    my (%params) = @_;

    $self->{response_limit} = $params{response_limit} || 128 * 1024;

    push @{$self->{allowed_methods}}, 'POST';

    return $self;
}

sub dispatch_POST {
    my $self = shift;
    my ($env, $conn) = @_;

    my $limit = $self->{response_limit};

    return sub {
        my $respond = shift;

        my $origin       = $env->{HTTP_ORIGIN};
        my @cors_headers = (
            'Access-Control-Allow-Origin' => !$origin
              || $origin eq 'null' ? '*' : $origin,
            'Access-Control-Allow-Credentials' => 'true'
        );

        my $writer = $respond->(
            [   200,
                [   'Content-Type' => 'application/javascript; charset=UTF-8',
                    'Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0',
                    @cors_headers
                ]
            ]
        );

        $writer->write(('h' x 2048) . "\n");

        if ($conn->is_connected && !$conn->is_reconnecting) {
            $writer->write('c[2010,"Another connection still open"]' . "\n");
            $writer->write('');
            $writer->close;
            return;
        }

        $conn->write_cb(
            sub {
                my $conn = shift;
                my ($message) = @_;

                $writer->write($message . "\n");

                $limit -= length($message) - 1;

                if ($limit <= 0) {
                    $writer->write('');
                    $writer->close;

                    $conn->reconnecting;
                }
            }
        );

        $conn->close_cb(
            sub {
                my $conn = shift;

                $writer->write('');
                $writer->close;
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
            $limit -= 4;
            $conn->write('o');

            $conn->connected;
        }
    };
}

1;
