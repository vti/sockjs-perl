use strict;
use warnings;

use Test::More;
use Test::MonkeyMock;

use SockJS::Connection;
use SockJS::Transport::JSONPPolling;

subtest 'return error when no callback found' => sub {
    my $transport = _build_transport();

    my $res = $transport->dispatch(
        {REQUEST_METHOD => 'GET', QUERY_STRING => 'foo=bar'});

    is_deeply $res, [500, [], ['"callback" parameter required']];
};

subtest 'return error when callback is invalid' => sub {
    my $transport = _build_transport();

    my $res =
      $transport->dispatch({REQUEST_METHOD => 'GET', QUERY_STRING => 'c=^&#$'});

    is_deeply $res, [500, [], ['invalid "callback" parameter']];
};

subtest 'write correct headers' => sub {
    my $transport = _build_transport();
    my $conn      = _build_conn();

    my $respond =
      $transport->dispatch({REQUEST_METHOD => 'GET', QUERY_STRING => 'c=foo'},
        $conn);

    my $writer = _mock_writer();

    my @written;
    $respond->(sub { push @written, @_; $writer });

    is_deeply $written[0],
      [
        200,
        [
            'Content-Type'  => 'application/javascript; charset=UTF-8',
            'Connection'    => 'close',
            'Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0'
        ]
      ];
};

subtest 'return error when connection already open' => sub {
    my $transport = _build_transport();
    my $conn      = _build_conn();

    $conn->connected;

    my $respond =
      $transport->dispatch({REQUEST_METHOD => 'GET', QUERY_STRING => 'c=foo'},
        $conn);

    my $writer = _mock_writer();

    $respond->(sub { $writer });

    my ($written) = $writer->mocked_call_args('write');

    is $written, qq{foo("c[2010,\\"Another connection still open\\"]\\\n");\r\n};
};

subtest 'write on connect' => sub {
    my $transport = _build_transport();
    my $conn      = _build_conn();

    my $respond =
      $transport->dispatch({REQUEST_METHOD => 'GET', QUERY_STRING => 'c=foo'},
        $conn);

    my $writer = _mock_writer();

    $respond->(sub { $writer });

    my ($written) = $writer->mocked_call_args('write');

    is $written, qq{foo("o");\r\n};
};

subtest 'write close frame when already closed' => sub {
    my $transport = _build_transport();
    my $conn      = _build_conn();

    $conn->connected;
    $conn->close;

    my $respond =
      $transport->dispatch({REQUEST_METHOD => 'GET', QUERY_STRING => 'c=foo'},
        $conn);

    my $writer = _mock_writer();

    $respond->(sub { $writer });

    my ($written) = $writer->mocked_call_args('write');

    is $written, qq{foo("c[3000,\\"Get away!\\"]");\r\n};
};

done_testing;

sub _mock_writer {
    my $writer = Test::MonkeyMock->new;
    $writer->mock(write => sub { });
    $writer->mock(close => sub { });
    return $writer;
}

sub _build_conn {
    SockJS::Connection->new(@_);
}

sub _build_transport {
    SockJS::Transport::JSONPPolling->new(@_);
}
