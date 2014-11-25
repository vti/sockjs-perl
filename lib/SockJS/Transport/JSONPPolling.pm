package SockJS::Transport::JSONPPolling;

use strict;
use warnings;

use base 'SockJS::Transport::Base';

sub new {
    my $self = shift->SUPER::new(@_);

    push @{$self->{allowed_methods}}, 'GET';

    return $self;
}

sub dispatch_GET {
    my $self = shift;
    my ($env, $conn, $path) = @_;

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

        if ($conn->is_connected && !$conn->is_reconnecting) {
            my $message = $self->_wrap_message($callback,
                'c[2010,"Another connection still open"]' . "\n");
            $writer->write($message);
            $writer->close;
            return;
        }

        $conn->write_cb(
            sub {
                my $conn = shift;
                my ($message) = @_;

                $message = $self->_wrap_message($callback, $message);

                $writer->write($message);
                $writer->write('');
                $writer->close;

                $conn->reconnecting if $conn->is_connected;
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

sub _wrap_message {
    my $self = shift;
    my ($callback, $message) = @_;

    $message =~ s/(['""\\\/\n\r\t]{1})/\\$1/smg;
    $message = qq{$callback("$message");\r\n};

    return $message;
}

1;
