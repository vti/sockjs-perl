use strict;
use warnings;

use Test::More;

use SockJS::Middleware::Cors;

subtest 'defaults' => sub {
    my $mw = _build_middleware();

    my $env = {};

    my $res = $mw->call($env);

    is_deeply { @{ $res->[1] } },
      {
        'Access-Control-Allow-Origin'      => '*',
        'Access-Control-Allow-Credentials' => 'true'
      };
};

done_testing;

sub _build_middleware {
    return SockJS::Middleware::Cors->new(
        app => sub { [ 200, [], ['OK'] ] },
        @_
    );
}
