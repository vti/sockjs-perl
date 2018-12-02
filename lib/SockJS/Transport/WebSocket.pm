package SockJS::Transport::WebSocket;

use strict;
use warnings;

use base 'SockJS::Transport::Base';

use Encode ();
use IO::Compress::Deflate;
use JSON ();
use AnyEvent::Handle;
use Protocol::WebSocket::Handshake::Server;

sub new {
    my $self = shift->SUPER::new(@_);

    push @{$self->{allowed_methods}}, 'GET';

    return $self;
}

sub dispatch_GET {
    my $self = shift;
    my ($env, $conn) = @_;

    my $hs = $self->{hs} =
      Protocol::WebSocket::Handshake::Server->new_from_psgi($env);

    my $fh = $env->{'psgix.io'};

    my $handle = $self->{handle} = $self->_build_handle(fh => $fh);

    $hs->parse($fh)
      or return $self->_return_error('Can "Upgrade" only to "WebSocket".',
        status => 400);

    return sub {
        my $on_close_cb = sub {
            my $handle = shift;

            $conn->aborted;

            if ($handle) {
                $handle->push_shutdown;
                $handle->destroy;
                delete $self->{handle};
                undef $handle;
            }
        };
        $handle->on_eof($on_close_cb);
        $handle->on_error($on_close_cb);

        $handle->on_read(
            sub {
                $handle->push_read(
                    sub {
                        $self->_parse($conn, $_[0]->rbuf) or do {
                            $conn->aborted;

                            $handle->push_shutdown;
                            $handle->destroy;
                            delete $self->{handle};
                            undef $handle;
                        };
                    }
                );
            }
        );

        $self->_parse($conn, '');
    };
}

sub _parse {
    my $self = shift;
    my ($conn) = @_;

    my $hs     = $self->{hs};
    my $handle = $self->{handle};

    if (!$self->{handshake_done}) {
        my $ok = $hs->parse($_[1]);
        return unless $ok;

        #$hs->res->push_header('Sec-WebSocket-Extensions' => 'permessage-deflate');

        # Partial request (HAProxy?)
        if ($hs->is_body) {
            $handle->push_write($hs->to_string);
            return 1;
        }

        if ($hs->is_done) {

            # Connected!
            $handle->push_write($hs->to_string);
            $self->{handshake_done}++;

            $conn->write_cb(
                sub {
                    my $conn = shift;
                    my ($message) = @_;

                    my $bytes = $hs->build_frame(buffer => $message)->to_bytes;

                    $handle->push_write($bytes) if $handle;
                }
            );
            $conn->close_cb(
                sub {
                    my $conn = shift;

                    my $close_frame = $hs->build_frame(type => 'close')->to_bytes;
                    $conn->write($close_frame);

                    if ($handle) {
                        $handle->push_shutdown;
                        $handle->destroy;
                        delete $self->{handle};
                        undef $handle;
                    }
                }
            );

            $conn->write('o') unless $self->name eq 'raw_websocket';
            $conn->connected;
        }
        else {

            # Wait for more data
            return 1;
        }
    }

    my $frame = $hs->build_frame;
    $frame->append($_[1]);

    while (defined(my $message = $frame->next_bytes)) {
        next unless length $message;

        if ($frame->rsv && $frame->rsv->[0]) {
            my $uncompressed;

            $message .= "\x00\x00\xff\xff";

            IO::Compress::Deflate::deflate(\$message => \$uncompressed)
                or return;
            $message = $uncompressed;
        }

        if ($self->name eq 'websocket') {
            my $json = JSON->new->utf8->allow_nonref(0);

            eval { $message = $json->decode($message) } || do {
                #warn "JSON error: $@\n";
                return;
            };

            return unless $message && ref $message eq 'ARRAY';
        }
        else {

            # We want to pass message AS IS
            $message = [\Encode::decode('UTF-8', $message)];
        }

        $conn->fire_event('data', @$message);
    }

    if ($frame->is_close) {
        $conn->close;
    }

    return 1;
}

sub _build_handle {
    my $self = shift;

    return AnyEvent::Handle->new(@_);
}

1;
