package SockJS::Transport::HtmlFile;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub dispatch {
    my $self = shift;
    my ($env, $session, $path) = @_;

    my ($callback) = $env->{QUERY_STRING} =~ m/(?:^|&|;)c=([^&;]+)/;
    if (!$callback) {
        return [500, ['Content-Length' => 29], ['"callback" parameter required']];
    }

    $callback =~ s/%(..)/chr(hex($1))/eg;
    if ($callback !~ m/^[a-zA-Z0-9-_\.]+$/) {
        return [500, ['Content-Length' => 28], ['invalid "callback" parameter']];
    }

    my $limit = 4096;

    return sub {
        my $respond = shift;

        my $writer = $respond->(
            [   200,
                [   'Content-Type' => 'text/html; charset=UTF-8',
                    'Connection'   => 'close',
                    'Cache-Control' =>
                      'no-store, no-cache, must-revalidate, max-age=0'
                ]
            ]
        );

        $session->on(
            write => sub {
                my $session = shift;

                my $message = 'a' . JSON::encode_json([@_]);

                $limit -= length($message) - 1;

                $writer->write($self->_wrap_message($message));

                if ($limit <= 0) {
                    $session->on(write => undef);
                    $session->reconnecting;

                    $writer->close;
                }
            }
        );

        $session->on(
            close => sub {
                my $session = shift;
                my ($code, $message) = @_;

                $writer->close;
            }
        );

        $writer->write(<<"EOF");
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

        $writer->write($self->_wrap_message('o'));

        if ($session->is_connected) {
            $session->reconnected;
        }
        else {
            $session->connected;
        }
    };
}

sub _wrap_message {
    my $self = shift;
    my ($message) = @_;

    $message =~ s{"}{\\"}smg;
    return qq{<script>\np("$message");\n</script>\r\n};
}

1;
