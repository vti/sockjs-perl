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

    $env->{'sockjs.cacheable'}       = $self->{cacheable};
    $env->{'sockjs.allowed_methods'} = $self->{allowed_methods};

    my $method = $env->{REQUEST_METHOD};
    if ( !grep { $_ eq $method } @{ $self->{allowed_methods} } ) {
        return [ 405, [ 'Allow' => join ', ', @{ $self->{allowed_methods} } ],
            [''] ];
    }

    $method = "dispatch_$method";
    return $self->$method(@_);
}

sub dispatch_OPTIONS {
    my $self = shift;
    my ($env) = @_;

    $env->{'sockjs.cacheable'} = 1;

    return [ 204, [], [''] ];
}

sub _return_error {
    my $self = shift;
    my ( $error, %params ) = @_;

    return [
        $params{status} || 500,
        [
            'Content-Type'   => 'text/plain; charset=UTF-8',
            'Content-Length' => length($error),
            $params{headers} ? @{ $params{headers} } : ()
        ],
        [$error]
    ];
}

1;
