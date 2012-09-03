package SockJS::Middleware::Http10;

use strict;
use warnings;

use parent 'Plack::Middleware';

use Plack::Util;

sub call {
    my $self = shift;
    my ($env) = @_;

    my $res = $self->app->($env);

    $self->response_cb(
        $res => sub {
            my $res = shift;
            my $h   = Plack::Util::headers($res->[1]);

            if (    $env->{'SERVER_PROTOCOL'} eq 'HTTP/1.0'
                and !$h->exists('Content-Length')
                and !$h->exists('Connection'))
            {
                $h->set('Connection' => 'close');
                return;
            }
        }
    );
}

1;
