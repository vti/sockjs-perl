package SockJS::Transport::JSONPSend;

use strict;
use warnings;

use base 'SockJS::Transport::Base';

use JSON ();

sub new {
    my $self = shift->SUPER::new(@_);

    push @{$self->{allowed_methods}}, 'POST';

    return $self;
}

sub dispatch_POST {
    my $self = shift;
    my ($env, $conn) = @_;

    return [404, [], ['Not found']] unless $conn->is_connected;

    my $data = $self->_get_content($env);
    return $data if $data && ref $data eq 'ARRAY';

    my $message;
    eval { $message = JSON::decode_json($data) } || do {
        return $self->_return_error('Broken JSON encoding.');
    };

    if ($message && ref $message eq 'ARRAY') {
        $conn->fire_event('data', @$message);
    }

    return [
        200,
        [
            'Content-Type'                     => 'text/plain; charset=UTF-8',
            'Content-Length'                   => 2,
            'Access-Control-Allow-Origin'      => '*',
            'Access-Control-Allow-Credentials' => 'true',
            'Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0',
        ],
        ['ok']
    ];
}

sub _get_content {
    my $self = shift;
    my ($env) = @_;

    my $content_length = $env->{CONTENT_LENGTH} || 0;
    my $rcount = $env->{'psgi.input'}->read(my $chunk, $content_length);

    return $self->_return_error('System error')
      unless $rcount == $content_length;

    my $d;

    if (   $env->{CONTENT_TYPE}
        && $env->{CONTENT_TYPE} eq 'application/x-www-form-urlencoded')
    {
        $chunk =~ s{\+}{ }g;
        ($d) = $chunk =~ m/(?:^|&|;)d=([^&;]*)/;
        $d =~ s/%(..)/chr(hex($1))/eg if defined $d;
    }
    else {
        $d = $chunk;
    }

    return $self->_return_error('Payload expected.') unless length $d;

    return $d;
}

1;
