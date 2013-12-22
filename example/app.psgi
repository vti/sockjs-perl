#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename;

use Plack::Builder;

use SockJS;

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
    mount '/echo' => SockJS->new(
        handler    => $echo,
        sockjs_url => '/sockjs-0.3.4.min.js',
        chunked    => $ENV{SOCKJS_CHUNKED}
    );

    mount '/' => builder {
        enable "Plack::Middleware::Static",
          path => qr{\.(?:html|js|css)$},
          root => "$root/public";

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
