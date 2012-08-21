package SockJS::Transport::Base;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{allowed_methods} = ['OPTIONS'];

    return $self;
}

sub name { shift->{name} }

sub dispatch {
    my $self = shift;
    my ($env, $session, $path) = @_;

    my $method = $env->{REQUEST_METHOD};
    if (!grep { $_ eq $method } @{$self->{allowed_methods}}) {
        return [400, [], ['Bad request']];
    }

    $method = "dispatch_$method";
    return $self->$method(@_);
}

sub dispatch_OPTIONS {
    my $self = shift;
    my ($env, $session, $path) = @_;

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
            'Access-Control-Max-Age' => '31536000',
            @cors_headers
        ],
        ['']
    ];
}

1;
