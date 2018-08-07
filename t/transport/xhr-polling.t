use strict;
use warnings;

use Test::More;
use Test::MonkeyMock;

use SockJS::Connection;
use SockJS::Transport::XHRPolling;

subtest 'return error when connection already open' => sub {
    my $transport = _build_transport();
    my $conn      = _build_conn();

    $conn->connected;

    my $respond = $transport->dispatch({REQUEST_METHOD => 'POST'}, $conn);

    my @written;
    $respond->(sub { @written = @_ });

    is_deeply \@written,
      [
        [
            200,
            [ 'Content-Type' => 'application/javascript; charset=UTF-8', ],
            [qq{c[2010,"Another connection still open"]\n}]
        ]
      ];
};

subtest 'write on connect' => sub {
    my $transport = _build_transport();
    my $conn      = _build_conn();

    my $respond = $transport->dispatch({REQUEST_METHOD => 'POST'}, $conn);

    my @written;
    $respond->(sub { @written = @_ });

    is_deeply \@written,
      [
        [
            200, [ 'Content-Type' => 'application/javascript; charset=UTF-8', ],
            [qq{o\n}]
        ]
      ];
};

subtest 'repeat close frame when already closed' => sub {
    my $transport = _build_transport();
    my $conn      = _build_conn();

    $conn->connected;
    $conn->close;

    my $respond = $transport->dispatch({REQUEST_METHOD => 'POST'}, $conn);

    my @written;
    $respond->(sub { @written = @_ });

    my $body = $written[0]->[2]->[0];

    is $body, qq{c[3000,"Get away!"]\n};
};

done_testing;

sub _build_conn {
    SockJS::Connection->new(@_);
}

sub _build_transport {
    SockJS::Transport::XHRPolling->new(@_);
}
