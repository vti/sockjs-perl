use strict;
use warnings;

use Test::More;

use SockJS::Middleware::JSessionID;

subtest 'echo cookie' => sub {
    my $mw = _build_middleware();

    $mw->wrap(sub { [200, [], []] });

    my $env = {
        'HTTP_COOKIE'      => 'JSESSIONID=abcde',
        'sockjs.transport' => 'xhr_polling'
    };

    my $response = $mw->call($env);

    is_deeply($response->[1], ['Set-Cookie' => 'JSESSIONID=abcde; Path=/']);
};

subtest 'echo cookie smart' => sub {
    my $mw = _build_middleware();

    $mw->wrap(sub { [200, [], []] });

    my $env = {
        'HTTP_COOKIE'      => 'foo=bar;JSESSIONID =    abcde;bar=baz',
        'sockjs.transport' => 'xhr_polling'
    };

    my $response = $mw->call($env);

    is_deeply($response->[1], ['Set-Cookie' => 'JSESSIONID=abcde; Path=/']);
};

subtest 'set default cookie' => sub {
    my $mw = _build_middleware(cookie => 1);

    $mw->wrap(sub { [200, [], []] });

    my $env = {'sockjs.transport' => 'xhr_polling'};

    my $response = $mw->call($env);

    is_deeply($response->[1], ['Set-Cookie' => 'JSESSIONID=dummy; Path=/']);
};

done_testing;

sub _build_middleware {
    return SockJS::Middleware::JSessionID->new(@_);
}
