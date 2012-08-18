package SockJS::Transport::WebSocket;

use strict;
use warnings;

use Protocol::WebSocket::Handshake::Server;

use SockJS::Handle;
use SockJS::Exception;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub dispatch {
    my $self = shift;
    my ($env, $session) = @_;

    return [405, ['Allow' => 'GET', 'Content-Length' => 0], []]
      unless $env->{REQUEST_METHOD} eq 'GET';

    my $handle = SockJS::Handle->new(fh => $env->{'psgix.io'});

    my $hs = Protocol::WebSocket::Handshake::Server->new_from_psgi($env);

    $hs->parse($handle->fh)
      or
      return $self->_return_error(400, 'Can "Upgrade" only to "WebSocket".');

    return sub {
        my $respond = shift;

        # Partial request (HAProxy?)
        if ($hs->is_body) {
            $handle->on_read(
                sub {
                    $hs->parse($_[1]);

                    if ($hs->is_done) {
                        $handle->write($hs->to_string =>
                              $self->_handshake_written_cb($hs, $session));
                    }
                }
            );

            $handle->write($hs->to_string);
        }
        elsif ($hs->is_done) {
            $handle->write(
                $hs->to_string => $self->_handshake_written_cb($hs, $session)
            );
        }
        else {
            $handle->close;
        }
    };
}

sub _return_error {
    my $self = shift;
    my ($code, $message) = @_;

    return [$code, ['Content-Length' => length $message], [$message]];
}

sub _handshake_written_cb {
    my $self = shift;
    my ($hs, $session) = @_;

    return sub {
        my $handle = shift;

        my $frame = $hs->build_frame;

        my $close_cb = sub {
            $session->event('closed');

            $handle->close;
        };
        $handle->on_eof($close_cb);
        $handle->on_error($close_cb);

        #$handle->on_heartbeat(sub { $conn->send_heartbeat });

        $handle->on_read(
            sub {
                $frame->append($_[1]);

                while (my $message = $frame->next_bytes) {
                    next unless length $message;

                    eval { $message = JSON::decode_json($message) } || do {
                        $close_cb->();
                        last;
                    };

                    next unless @$message;

                    $session->event('data', @$message);
                }

                if ($frame->is_close) {
                    $close_cb->();
                }
            }
        );

        $session->on(
            close => sub {

                # $handle->write(); TODO write WebSocket EOF
                $handle->close;
            }
        );

        $session->on(
            syswrite => sub {
                my $session = shift;
                my ($message) = @_;

                my $bytes = $hs->build_frame(buffer => $message)->to_bytes;

                $handle->write($bytes);
            }
        );

        $session->syswrite('o');
        $session->connected;
    };
}

1;
