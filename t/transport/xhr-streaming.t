use strict;
use warnings;

use Test::More;
use Test::MonkeyMock;

use SockJS::Connection;
use SockJS::Transport::XHRStreaming;

subtest 'return error when connection already open' => sub {
    my $transport = _build_transport();
    my $conn      = _build_conn();

    $conn->connected;

    my $respond = $transport->dispatch({REQUEST_METHOD => 'POST'}, $conn);

    my $writer = _mock_writer();
    $respond->(sub { $writer });

    my ($written) = $writer->mocked_call_args('write', 1);
    is $written, qq{c[2010,"Another connection still open"]\n};
};

subtest 'write data on connect' => sub {
    my $transport = _build_transport();
    my $conn      = _build_conn();

    my $respond = $transport->dispatch({REQUEST_METHOD => 'POST'}, $conn);

    my $writer = _mock_writer();
    $respond->(sub { $writer });

    my ($written) = $writer->mocked_call_args('write', 1);
    is $written, qq{o\n};
};

subtest 'repeat close frame when already closed' => sub {
    my $transport = _build_transport();
    my $conn      = _build_conn();

    $conn->connected;
    $conn->close;

    my $respond = $transport->dispatch({REQUEST_METHOD => 'POST'}, $conn);

    my $writer = _mock_writer();
    $respond->(sub { $writer });

    my ($written) = $writer->mocked_call_args('write', 1);
    is $written, qq{c[3000,"Get away!"]\n};
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
    SockJS::Transport::XHRStreaming->new(@_);
}
