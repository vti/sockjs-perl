package SockJS::Transport::XHRStreaming;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{response_limit} ||= 128 * 1024;

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

    my $limit = $self->{response_limit};

    return sub {
        my $respond = shift;

        my $chunked = $env->{SERVER_PROTOCOL} eq 'HTTP/1.1';

        my $writer = $respond->(
            [   200,
                [   'Content-Type' => 'application/javascript; charset=UTF-8',
                    'Access-Control-Allow-Origin'      => '*',
                    'Access-Control-Allow-Credentials' => 'true',
                    $chunked
                    ? ('Transfer-Encoding' => 'chunked')
                    : ()
                ]
            ]
        );

        if ($session->is_connected && !$session->is_reconnecting) {
            $writer->write($self->_build_chunk($chunked, ('h' x 2048) . "\n"));
            $writer->write(
                $self->_build_chunk(
                    $chunked, 'c[2010,"Another connection still open"]' . "\n"
                )
            );
            $writer->write($self->_build_chunk($chunked, ''));
            $writer->close;
        }

        my $handle = SockJS::Handle->new(fh => $env->{'psgix.io'});
        $handle->on_error(sub { $session->aborted });
        $handle->on_eof(sub   { $session->aborted });

        $writer->write($self->_build_chunk($chunked, ('h' x 2048) . "\n"));

        $session->on(
            syswrite => sub {
                my $session = shift;
                my ($message) = @_;

                $writer->write(
                    $self->_build_chunk($chunked, $message . "\n"));

                $limit -= length($message) - 1;

                if ($limit <= 0) {
                    $writer->write($self->_build_chunk($chunked, ''));
                    $writer->close;
                    $session->reconnecting;
                }
            }
        );

        $session->on(
            close => sub {
                my $session = shift;

                $writer->write($self->_build_chunk($chunked, ''));
                $writer->close;
            }
        );

        if ($session->is_closed) {
            $session->close;
        }
        else {
            $limit -= 4;
            $session->syswrite('o');

            if ($session->is_connected) {
                $session->reconnected;
            }
            else {
                $session->connected;
            }
        }
    };
}

sub _build_chunk {
    my $self = shift;
    my ($chunked, $chunk) = @_;

    return $chunk unless $chunked;

    return
        (unpack 'H*', pack 'N*', length($chunk))
      . "\x0d\x0a"
      . $chunk
      . "\x0d\x0a";
}

1;
