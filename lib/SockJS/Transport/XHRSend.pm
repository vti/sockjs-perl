package SockJS::Transport::XHRSend;

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

    return [404, ['Content-Length' => 9], ['Not found']]
      unless $session->is_connected;

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
