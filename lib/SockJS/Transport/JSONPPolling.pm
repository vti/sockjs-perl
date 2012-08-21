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
        return [500, [], ['"callback" parameter required']];
    }

    $callback =~ s/%(..)/chr(hex($1))/eg;
    if ($callback !~ m/^[a-zA-Z0-9-_\.]+$/) {
        return [500, [], ['invalid "callback" parameter']];
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

        if ($session->is_connected && !$session->is_reconnecting) {
            my $message = $self->_wrap_message($callback,
                'c[2010,"Another connection still open"]' . "\n");
            $writer->close;
            return;
        }

        $session->on(
            syswrite => sub {
                my $session = shift;
                my ($message) = @_;

                $message = $self->_wrap_message($callback, $message);

                $writer->write($message);
                $writer->close;

                $session->reconnecting if $session->is_connected;
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

sub _wrap_message {
    my $self = shift;
    my ($callback, $message) = @_;

    $message =~ s/(['""\\\/\n\r\t]{1})/\\$1/smg;
    $message = qq{$callback("$message");\r\n};

    return $message;
}

1;
