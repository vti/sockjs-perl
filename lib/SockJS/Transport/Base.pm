package SockJS::Transport::Base;

use strict;
use warnings;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{name} = $params{name} || '';
    $self->{allowed_methods} = ['OPTIONS'];

    return $self;
}

sub name { shift->{name} }

sub dispatch {
    my $self = shift;
    my ($env) = @_;

    my $method = $env->{REQUEST_METHOD};
    if (!grep { $_ eq $method } @{$self->{allowed_methods}}) {
        return [
            405, ['Allow' => join ', ', @{$self->{allowed_methods}}],
            ['']
        ];
    }

    $method = "dispatch_$method";
    return $self->$method(@_);
}

sub dispatch_OPTIONS {
    my $self = shift;
    my ($env) = @_;

    my $origin       = $env->{HTTP_ORIGIN};
    my @cors_headers = (
        'Access-Control-Allow-Origin' => !$origin
          || $origin eq 'null' ? '*' : $origin,
        'Access-Control-Allow-Credentials' => 'true'
    );

    return [
        204,
        [   'Expires'       => '31536000',
            'Cache-Control' => 'public;max-age=31536000',
            'Access-Control-Allow-Methods' =>
              join(', ', @{$self->{allowed_methods}}),
            'Access-Control-Max-Age'       => '31536000',
            'Access-Control-Allow-Headers' => 'origin, content-type',
            @cors_headers
        ],
        ['']
    ];
}

sub _return_error {
    my $self = shift;
    my ($error, %params) = @_;

    return [
        $params{status} || 500,
        [
            'Content-Type'   => 'text/plain; charset=UTF-8',
            'Content-Length' => length($error),
            $params{headers} ? @{$params{headers}} : ()
        ],
        [$error]
    ];
}

1;
