package MiddlewareJSessionIDTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use SockJS::Middleware::JSessionID;

sub echo_cookie : Test {
    my $self = shift;

    my $mw = $self->_build_middleware;

    $mw->wrap(sub { [200, [], []] });

    my $env = {
        'HTTP_COOKIE'      => 'JSESSIONID=abcde',
        'sockjs.transport' => 'xhr_polling'
    };

    my $response = $mw->call($env);

    is_deeply($response->[1], ['Set-Cookie' => 'JSESSIONID=abcde; Path=/']);
}

sub echo_cookie_smart : Test {
    my $self = shift;

    my $mw = $self->_build_middleware;

    $mw->wrap(sub { [200, [], []] });

    my $env = {
        'HTTP_COOKIE'      => 'foo=bar;JSESSIONID =    abcde;bar=baz',
        'sockjs.transport' => 'xhr_polling'
    };

    my $response = $mw->call($env);

    is_deeply($response->[1], ['Set-Cookie' => 'JSESSIONID=abcde; Path=/']);
}

sub set_default_cookie : Test {
    my $self = shift;

    my $mw = $self->_build_middleware(cookie => 1);

    $mw->wrap(sub { [200, [], []] });

    my $env = {'sockjs.transport' => 'xhr_polling'};

    my $response = $mw->call($env);

    is_deeply($response->[1], ['Set-Cookie' => 'JSESSIONID=dummy; Path=/']);
}

sub _build_middleware {
    my $self = shift;

    return SockJS::Middleware::JSessionID->new(@_);
}

1;
