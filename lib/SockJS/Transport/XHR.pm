package SockJS::Transport::XHR;

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

    if ($path eq 'xhr' || $path eq 'xhr_streaming') {
        if ($session->is_connected && !$session->is_reconnecting) {
            return [
                200,
                ['Content-Length' => 40],
                [qq{c[2010,"Another connection still open"]\n}]
            ];
        }

        if ($path eq 'xhr') {
            return $self->_dispatch_polling($env, $session);
        }
        else {
            return $self->_dispatch_streaming($env, $session);
        }
    }
    elsif ($path eq 'xhr_send') {
        return [404, ['Content-Length' => 9], ['Not found']]
          unless $session->is_connected;

        return $self->_dispatch_send($env, $session);
    }

    return [404, ['Content-Length' => 9], ['Not Found']];
}

sub _dispatch_polling {
    my $self = shift;
    my ($env, $session) = @_;

    return sub {
        my $respond = shift;

        $session->on(
            write => sub {
                my $session = shift;

                my $message = 'a' . JSON::encode_json([@_]);

                $self->_write($env, $session, $respond, $message);
            }
        );

        $session->on(
            close => sub {
                my $session = shift;
                my ($code, $message) = @_;

                $code = int $code;

                $session->write(qq{c[$code,"$message"]});
            }
        );

        if ($session->is_connected) {
            $session->reconnected;
        }
        else {
            $self->_write($env, $session, $respond, 'o');

            $session->connected;
        }
    };
}

sub _dispatch_streaming {
    my $self = shift;
    my ($env, $session) = @_;

    my $limit = 4096;

    return sub {
        my $respond = shift;

        my $chunked = $env->{SERVER_PROTOCOL} eq 'HTTP/1.1';

        my $writer = $respond->(
            [   200,
                [   'Content-Type' => 'application/javascript; charset=UTF-8',
                    'Access-Control-Allow-Origin'      => '*',
                    'Access-Control-Allow-Credentials' => 'true',
                    $chunked ? ('Transfer-Encoding' => 'chunked')
                    : ()
                ]
            ]
        );

        $session->on(
            write => sub {
                my $session = shift;

                my $message = 'a' . JSON::encode_json([@_]);

                $writer->write($self->_build_chunk($chunked, $message . "\n"));

                $limit -= length($message) - 1;

                if ($limit <= 0) {
                    $session->on(write => undef);
                    $session->reconnecting;

                    $writer->write($self->_build_chunk($chunked, ''));
                    $writer->close;
                }
            }
        );

        $session->on(
            close => sub {
                my $session = shift;
                my ($code, $message) = @_;

                $code = int $code;

                $writer->write($self->_build_chunk($chunked, qq{c[$code,"$message"]} . "\n"));
                $writer->write($self->_build_chunk($chunked, ''));
                $writer->close;
            }
        );

        $writer->write($self->_build_chunk($chunked, ('h' x 2048) . "\n"));
        $limit -= 4;
        $writer->write($self->_build_chunk($chunked, 'o' . "\n"));

        if ($session->is_connected) {
            $session->reconnected;
        }
        else {
            $session->connected;
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

sub _dispatch_send {
    my $self = shift;
    my ($env, $session) = @_;

    my $data = $self->_get_content($env);

    return $self->_return_send_error('Payload expected.') unless length $data;

    my $message;
    eval { $message = JSON::decode_json($data) } || do {
        return $self->_return_send_error('Broken JSON encoding.');
    };

    if (@$message) {
        $session->event('data', @$message);
    }

    return [
        204,
        [   'Content-Length'                   => 0,
            'Content-Type'                     => 'text/plain; charset=UTF-8',
            'Access-Control-Allow-Origin'      => '*',
            'Access-Control-Allow-Credentials' => 'true'
        ],
        []
    ];
}

sub _get_content {
    my $self = shift;
    my ($env) = @_;

    my $content_length = $env->{CONTENT_LENGTH} || 0;
    my $rcount = $env->{'psgi.input'}->read(my $chunk, $content_length);

    SockJS::Exception->throw(500) unless $rcount == $content_length;

    return $chunk;
}

sub _write {
    my $self = shift;
    my ($env, $session, $respond, $message) = @_;

    $message .= "\n";

    $session->on(write => undef);

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

    $session->reconnecting;
}

sub _return_send_error {
    my $self = shift;
    my ($error) = @_;

    return [
        500,
        [   'Content-Length' => length($error),
            'Content-Type'   => 'text/plain; charset=UTF-8',
        ],
        [$error]
    ];
}

1;
