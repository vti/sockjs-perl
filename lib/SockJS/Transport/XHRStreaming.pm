package SockJS::Transport::XHRStreaming;

use strict;
use warnings;

use base 'SockJS::Transport::Base';

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{response_limit} ||= 128 * 1024;

    push @{$self->{allowed_methods}}, 'POST';

    return $self;
}

sub dispatch_POST {
    my $self = shift;
    my ($env, $session, $path) = @_;

    my $limit = $self->{response_limit};

    return sub {
        my $respond = shift;

        my $origin       = $env->{HTTP_ORIGIN};
        my @cors_headers = (
            'Access-Control-Allow-Origin' => !$origin
              || $origin eq 'null' ? '*' : $origin,
            'Access-Control-Allow-Credentials' => 'true'
        );

        my $writer = $respond->(
            [   200,
                [   'Content-Type' => 'application/javascript; charset=UTF-8',
                    @cors_headers
                ]
            ]
        );

        if ($session->is_connected && !$session->is_reconnecting) {
            $writer->write(('h' x 2048) . "\n");
            $writer->write('c[2010,"Another connection still open"]' . "\n");
            $writer->write('');
            $writer->close;
            return;
        }

        #my $handle = SockJS::Handle->new(fh => $env->{'psgix.io'});
        #$handle->on_error(sub { $session->aborted });
        #$handle->on_eof(sub   { $session->aborted });

        $writer->write(('h' x 2048) . "\n");

        $session->on(
            syswrite => sub {
                my $session = shift;
                my ($message) = @_;

                $writer->write($message . "\n");

                $limit -= length($message) - 1;

                if ($limit <= 0) {
                    $writer->write('');
                    $writer->close;
                    $session->reconnecting;
                }
            }
        );

        $session->on(
            close => sub {
                my $session = shift;

                $writer->write('');
                $writer->close;
            }
        );

        if ($session->is_closed) {
            $session->connected;
            $session->close;
        }
        else {
            $limit -= 4;
            $session->syswrite('o');

            if ($session->is_connected) {
                $session->reconnected;
            }
            else {
                $session->connected;
            }
        }
    };
}

1;
