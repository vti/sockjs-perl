use strict;
use warnings;

use Test::More;
use Test::Fatal;

use SockJS::Middleware::Cache;

subtest 'not cacheable' => sub {
    my $mw = _build_middleware();

    my $env = {};

    my $res = $mw->call($env);

    is_deeply $res->[1],
      [ 'Cache-Control' =>
          'no-store, no-cache, no-transform, must-revalidate, max-age=0' ];
};

subtest 'cacheable' => sub {
    my $mw = _build_middleware();

    my $env = { 'sockjs.cacheable' => 1 };

    my $res = $mw->call($env);

    is_deeply { @{ $res->[1] } },
      {
        'Expires'       => '31536000',
        'Cache-Control' => 'public;max-age=31536000'
      };
};

done_testing;

sub _build_middleware {
    return SockJS::Middleware::Cache->new(
        app => sub { [ 200, [], ['OK'] ] },
        @_
    );
}
