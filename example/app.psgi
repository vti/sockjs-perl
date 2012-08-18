#!/usr/bin/env perl

use strict;
use warnings;

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

builder {
    mount '/echo' => SockJS->new(handler => $echo);

    mount '/disabled_websocket_echo' =>
      SockJS->new(handler => $echo, websocket => 0);

    mount '/cookie_needed_echo' => SockJS->new(handler => $echo, cookie => 1);

    mount '/close' => SockJS->new(
        handler => sub {
            my $session = shift;

            $session->close(3000, 'Go away!');
        }
    );

    mount '/' => sub {
        my $env = shift;

        if ($env->{PATH_INFO} ne '/') {
            return [404, [], ['Not found']];
        }

        return [200, [], [<<'EOF']];
<script src="http://cdn.sockjs.org/sockjs-0.2.1.min.js"></script>

<script>
  var sock = new SockJS('http://localhost:8081/echo');

  sock.onopen = function() {
    console.log("open");
  };

  sock.onmessage = function(e) {
    console.log("message", e.data);
  };

  sock.onclose = function() {
    console.log("close");
  };
</script>
EOF
      }
};
