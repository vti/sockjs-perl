package SockJS::Transport::EventSource;

use strict;
use warnings;

use base 'SockJS::Transport::Base';

sub new {
    my $self = shift->SUPER::new(@_);
    my (%params) = @_;

    $self->{response_limit} = $params{response_limit} || 128 * 1024;

    push @{$self->{allowed_methods}}, 'GET';

    return $self;
}

sub dispatch_GET {
    my $self = shift;
    my ($env, $conn) = @_;

    my $limit = $self->{response_limit};

    return sub {
        my $respond = shift;

        my $writer = $respond->(
            [   200,
                [   'Content-Type' => 'text/event-stream; charset=UTF-8',
                    'Cache-Control' =>
                      'no-store, no-cache, must-revalidate, max-age=0'
                ]
            ]
        );

        if ($conn->is_connected && !$conn->is_reconnecting) {
            $writer->write("\x0d\x0a");
            $writer->write(
                qq{data: c[2010,"Another connection still open"]\x0d\x0a\x0d\x0a\n}
            );
            $writer->close;
            return;
        }

        $conn->write_cb(
            sub {
                my $conn = shift;
                my ($message) = @_;

                $limit -= length($message) - 1;

                $writer->write("data: $message\x0d\x0a\x0d\x0a");

                if ($limit <= 0) {
                    $writer->close;

                    $conn->reconnecting;
                }
            }
        );

        $conn->on(close => sub { $writer->close });

        $writer->write("\x0d\x0a");
        $conn->write('o');

        if ($conn->is_closed) {
            $conn->connected;
            $conn->close;
        }
        elsif ($conn->is_connected) {
            $conn->reconnected;
        }
        else {
            $conn->connected;
        }
    };
}

1;
