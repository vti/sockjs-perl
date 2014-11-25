use strict;
use warnings;

use Test::More;
use Test::MonkeyMock;

use SockJS::Connection;
use SockJS::Transport::WebSocket;

subtest 'return error when invalid WebSocket handshake' => sub {
    my $transport = _build_transport();
    my $conn      = _build_conn();

    my $input = 'foobar';
    open my $fh, '<', \$input;

    my $res = $transport->dispatch(
        {
            REQUEST_METHOD => 'GET',
            SCRIPT_NAME    => '',
            PATH_INFO      => '',
            'psgix.io'     => $fh
        },
        $conn
    );

    is_deeply $res,
      [
        400,
        ['Content-Type' => 'text/plain; charset=UTF-8', 'Content-Length' => 34],
        ['Can "Upgrade" only to "WebSocket".']
      ];
};

subtest 'send handshake back' => sub {
    my $handle    = _mock_handle();
    my $transport = _build_transport(handle => $handle);
    my $conn      = _build_conn();

    my $input = '';
    open my $fh, '+<', \$input;

    my $respond = $transport->dispatch(_fake_env('psgix.io' => $fh), $conn);

    $respond->();

    my ($stack) = $handle->mocked_call_stack('push_write');
    my $written = join '', map { $_->[0] } @$stack;

    like $written, qr/o$/;
};

subtest 'send message on connect' => sub {
    my $handle    = _mock_handle();
    my $transport = _build_transport(handle => $handle);
    my $conn      = _build_conn();

    my $input = '';
    open my $fh, '+<', \$input;

    my $respond = $transport->dispatch(_fake_env('psgix.io' => $fh), $conn);

    $respond->();

    my ($stack) = $handle->mocked_call_stack('push_write');
    my $written = join '', map { $_->[0] } @$stack;

    like $written, qr/o$/;
};

done_testing;

sub _build_conn {
    SockJS::Connection->new(@_);
}

sub _fake_env {
    {
        REQUEST_METHOD              => 'GET',
        SCRIPT_NAME                 => '',
        PATH_INFO                   => '/chat',
        QUERY_STRING                => 'foo=bar',
        HTTP_UPGRADE                => 'websocket',
        HTTP_CONNECTION             => 'Upgrade',
        HTTP_HOST                   => 'server.example.com',
        HTTP_COOKIE                 => 'foo=bar',
        HTTP_SEC_WEBSOCKET_ORIGIN   => 'http://example.com',
        HTTP_SEC_WEBSOCKET_PROTOCOL => 'chat, superchat',
        HTTP_SEC_WEBSOCKET_KEY      => 'dGhlIHNhbXBsZSBub25jZQ==',
        HTTP_SEC_WEBSOCKET_VERSION  => 13,
        @_
    };
}

sub _mock_handle {
    my (%params) = @_;

    my $handle = Test::MonkeyMock->new;
    $handle->mock(on_eof     => sub { });
    $handle->mock(on_error   => sub { });
    $handle->mock(on_read    => sub { $_[1]->() });
    $handle->mock(push_read  => sub { $_[1]->($_[0]) });
    $handle->mock(rbuf       => sub { '' });
    $handle->mock(push_write => sub { });

    return $handle;
}

sub _build_transport {
    my (%params) = @_;

    my $handle = $params{handle} || _mock_handle();

    my $transport = SockJS::Transport::WebSocket->new(@_);
    $transport = Test::MonkeyMock->new($transport);
    $transport->mock(_build_handle => sub { $handle });

    return $transport;
}
