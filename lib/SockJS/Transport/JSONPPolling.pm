package SockJS::Transport::JSONPPolling;

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

    my ($callback) = $env->{QUERY_STRING} =~ m/(?:^|&|;)c=([^&;]+)/;
    if (!$callback) {
        return [
            500, ['Content-Length' => 29],
            ['"callback" parameter required']
        ];
    }

    $callback =~ s/%(..)/chr(hex($1))/eg;
    if ($callback !~ m/^[a-zA-Z0-9-_\.]+$/) {
        return [
            500, ['Content-Length' => 28],
            ['invalid "callback" parameter']
        ];
    }

    return sub {
        my $respond = shift;

        my $writer = $respond->(
            [   200,
                [   'Content-Type' => 'application/javascript; charset=UTF-8',
                    'Connection'   => 'close',
                    'Cache-Control' =>
                      'no-store, no-cache, must-revalidate, max-age=0'
                ]
            ]
        );

        $session->on(
            syswrite => sub {
                my $session = shift;
                my ($message) = @_;

                $message =~ s{"}{\\"}smg;
                $message = qq{$callback("$message");\r\n};

                $writer->write($message);
                $writer->close;

                $session->reconnecting if $session->is_connected;
            }
        );

        if ($session->is_connected) {
            $session->reconnected;
        }
        else {
            $session->syswrite('o');
            $session->connected;
        }
    };
}

1;
