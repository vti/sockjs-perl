package SockJS::Middleware::Cors;

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

            my $origin = $env->{HTTP_ORIGIN} // '';

            my %cors_headers = (
                  'Access-Control-Allow-Origin' => ( $origin eq '' )
                ? '*'
                : $origin,
                'Access-Control-Allow-Credentials' => 'true'
            );

            if ( my $request_headers =
                $env->{HTTP_ACCESS_CONTROL_REQUEST_HEADERS} )
            {
                $cors_headers{'Access-Control-Allow-Headers'} =
                  $request_headers;
            }

            if ( my $allowed_methods = $env->{'sockjs.allowed_methods'} ) {
                $cors_headers{'Access-Control-Allow-Methods'} =
                  join( ', ', @$allowed_methods );
            }

            if ($env->{'sockjs.cacheable'}) {
                $cors_headers{'Access-Control-Max-Age'} = '31536000';
            }

            foreach my $header ( keys %cors_headers ) {
                $h->push( $header => $cors_headers{$header} );
            }
        }
    );
}

1;
