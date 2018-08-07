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
    response_limit => 4096,
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
