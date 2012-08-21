package SockJS::Middleware::JSessionID;

use strict;
use warnings;

use parent 'Plack::Middleware';

use Plack::Util;

sub call {
    my $self = shift;
    my ($env) = @_;

    my $res = $self->app->(@_);
    return $res unless $env->{'sockjs.transport'};

    return $self->response_cb(
        $res => sub {
            my $res = shift;

            my $h = Plack::Util::headers($res->[1]);

            if (my $cookie = $env->{HTTP_COOKIE}) {
                if ($cookie =~ m/(?:^|;|\s)JSESSIONID\s*=\s*(.+?)(?:\s|;|$)/) {
                    $h->push('Set-Cookie' => "JSESSIONID=$1; Path=/");
                }
            }
            elsif ($self->{cookie}) {
                $h->push('Set-Cookie' => 'JSESSIONID=dummy; Path=/');
            }
        }
    );
}

1;
