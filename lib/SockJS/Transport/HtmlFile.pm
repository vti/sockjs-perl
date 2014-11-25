package SockJS::Transport::HtmlFile;

use strict;
use warnings;

use base 'SockJS::Transport::Base';

sub new {
    my $self = shift->SUPER::new(@_);
    my (%params) = @_;

    $self->{response_limit} = $params{response_limit} || 128 * 1024;

    push @{$self->{allowed_methods}}, 'GET';

    return $self;
}

sub dispatch_GET {
    my $self = shift;
    my ($env, $conn) = @_;

    my ($callback) = $env->{QUERY_STRING} =~ m/(?:^|&|;)c=([^&;]+)/;
    if (!$callback) {
        return [500, [], ['"callback" parameter required']];
    }

    $callback =~ s/%(..)/chr(hex($1))/eg;
    if ($callback !~ m/^[a-zA-Z0-9-_\.]+$/) {
        return [500, [], ['invalid "callback" parameter']];
    }

    my $limit = $self->{response_limit};

    return sub {
        my $respond = shift;

        my $writer = $respond->(
            [
                200,
                [
                    'Content-Type' => 'text/html; charset=UTF-8',
                    'Connection'   => 'close',
                    'Cache-Control' =>
                      'no-store, no-cache, must-revalidate, max-age=0'
                ]
            ]
        );

        if ($conn->is_connected && !$conn->is_reconnecting) {
            my $message = $self->_wrap_message(
                'c[2010,"Another connection still open"]' . "\n");
            $writer->write($message);
            $writer->close;
            return;
        }

        $conn->write_cb(
            sub {
                my $conn = shift;
                my ($message) = @_;

                $limit -= length($message) - 1;

                $writer->write($self->_wrap_message($message));

                if ($limit <= 0) {
                    $writer->close;

                    $conn->reconnecting;
                }
            }
        );

        $conn->close_cb(sub { $writer->close });

        $writer->write((' ' x 1024) . <<"EOF");
<!doctype html>
<html><head>
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
</head><body><h2>Don't panic!</h2>
  <script>
    document.domain = document.domain;
    var c = parent.$callback;
    c.start();
    function p(d) {c.message(d);};
    window.onload = function() {c.stop();};
  </script>
EOF

        $conn->write('o');

        if ($conn->is_closed) {
            $conn->connected;
            $conn->close;
        }
        elsif ($conn->is_connected) {
            $conn->reconnected;
        }
        else {
            $conn->connected;
        }
    };
}

sub _wrap_message {
    my $self = shift;
    my ($message) = @_;

    $message =~ s/(['""\\\/\n\r\t]{1})/\\$1/smg;
    return qq{<script>\np("$message");\n</script>\r\n};
}

1;
