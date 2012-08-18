package SockJS::Transport::EventSource;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub dispatch {
    my $self = shift;
    my ($env, $session, $path) = @_;

    my $limit = 4096;

    return sub {
        my $respond = shift;

        my $writer = $respond->(
            [   200,
                [   'Content-Type' => 'text/event-stream; charset=UTF-8',
                    'Connection'   => 'close',
                    'Cache-Control' =>
                      'no-store, no-cache, must-revalidate, max-age=0'
                ]
            ]
        );

        $session->on(
            write => sub {
                my $session = shift;

                my $message = 'a' . JSON::encode_json([@_]);

                $limit -= length($message) - 1;

                $writer->write("data: $message\x0d\x0a\x0d\x0a");

                if ($limit <= 0) {
                    $session->on(write => undef);
                    $session->reconnecting;

                    $writer->close;
                }
            }
        );

        $session->on(
            close => sub {
                my $session = shift;
                my ($code, $message) = @_;

                $writer->close;
            }
        );

        $writer->write("\x0d\x0a");
        $writer->write("data: o\x0d\x0a\x0d\x0a");

        if ($session->is_connected) {
            $session->reconnected;
        }
        else {
            $session->connected;
        }
    };
}

1;
