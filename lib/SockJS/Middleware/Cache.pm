package SockJS::Middleware::Cache;

use strict;
use warnings;

use parent 'Plack::Middleware';

use Plack::Util;

sub call {
    my $self = shift;
    my ($env) = @_;

    my $res = $self->app->(@_);

    return $self->response_cb(
        $res => sub {
            my $res = shift;

            my $h = Plack::Util::headers( $res->[1] );

            if ($env->{'sockjs.cacheable'}) {
                $h->set('Expires'        => '31536000');
                $h->set('Cache-Control'  => 'public;max-age=31536000');
            }
            else {
                $h->set('Cache-Control' => 'no-store, no-cache, no-transform, must-revalidate, max-age=0');
            }
        }
    );
}

1;
