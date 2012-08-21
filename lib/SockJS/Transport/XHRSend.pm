package SockJS::Transport::XHRSend;

use strict;
use warnings;

use base 'SockJS::Transport::Base';

use SockJS::Exception;

sub new {
    my $self = shift->SUPER::new(@_);

    push @{$self->{allowed_methods}}, 'POST';

    return $self;
}

sub dispatch_POST {
    my $self = shift;
    my ($env, $session, $path) = @_;

    return [404, [], ['Not found']] unless $session->is_connected;

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

    return [500, ['Content-Type' => 'text/plain; charset=UTF-8'], [$error]];
}

1;
