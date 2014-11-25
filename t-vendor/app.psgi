#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename;

use Plack::Builder;
use Plack::App::Directory;

BEGIN {
    my $root = File::Basename::dirname(__FILE__);

    unshift @INC, File::Spec->catfile($root, '..', 'lib');
}

use SockJS;

my %options = (
    response_limit => $ENV{TEST_PROTOCOL} ? 4096 : 128 * 1024,
    sockjs_url => '/lib/sockjs.js'
);

my $echo = sub {
    my ($session) = @_;

    $session->on(
        'data' => sub {
            my $session = shift;

            $session->write(@_);
        }
    );
};

my $root = File::Basename::dirname(__FILE__);

builder {
    mount '/config.js' => sub {
        my $body = <<'EOF';
var server_opts = {
    sockjs_url: 'http://localhost:8081/lib/sockjs.js'
};
var client_opts = {
    url: 'http://localhost:8081',
    sockjs_opts: {
        devel: true,
        debug: true,
        // websocket:false
        info: {cookie_needed:false}
    }
};
EOF

        [200, ['Content-Type' => 'application/javascript'], [$body]];
    };

    mount '/simple.txt' => sub {
        my $body = ('a' x 2048) . "\nb\n";

        [
            200,
            [
                'Content-Type'                => 'text/plain',
                'Access-Control-Allow-Origin' => '*'
            ],
            [$body]
        ];
    };

    mount '/streaming.txt' => sub {
        my $env = shift;

        my $t;

        return sub {
            my $respond = shift;

            my $writer = $respond->(
                [
                    200,
                    [
                        'Content-Type'                => 'text/plain',
                        'Access-Control-Allow-Origin' => '*'
                    ]
                ]
            );

            $writer->write('a' x 2048);
            $writer->write("\n");

            $t = AnyEvent->timer(
                after => .2,
                cb    => sub {
                    $writer->write("b\n");
                    $writer->close;
                }
            );
          }
    };

    mount '/lib/sockjs.js' => sub {
        my $body = do {
            local $/;
            open my $fh, '<', "$root/sockjs-0.3.2.min.js" or die $!;
            <$fh>;
        };
        [200, ['Content-Type' => 'application/javascript'], [$body]];
    };

    mount '/echo' => SockJS->new(%options, handler => $echo);

    mount '/disabled_websocket_echo' =>
      SockJS->new(%options, handler => $echo, websocket => 0);

    mount '/cookie_needed_echo' =>
      SockJS->new(%options, handler => $echo, cookie => 1);

    mount '/amplify' => SockJS->new(
        %options,
        handler => sub {
            my $session = shift;

            $session->on(
                'data',
                sub {
                    my $session = shift;

                    for my $m (@_) {
                        my $n = int $m;
                        $n = ($n > 0 && $n < 19) ? $n : 1;

                        $session->write('x' x (2 ** $n));
                    }
                }
            );
        }
    );

    mount '/close' => SockJS->new(
        %options,
        handler => sub {
            my $session = shift;

            $session->close(3000, 'Go away!');
        }
    );

    mount '/' => builder {
        enable "Plack::Middleware::Static",
          path => qr{\.(?:html|js|css)$},
          root => "$root/html";

        sub {
            my $env = shift;

            my $path_info = $env->{PATH_INFO};
            if ($path_info eq '' || $path_info eq '/') {
                return [302, [Location => '/index.html'], []];
            }

            return [404, ['Content-Length' => 0], []];
        };
    };
};
