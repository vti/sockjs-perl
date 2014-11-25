use strict;
use warnings;

use Test::More;
use Test::MonkeyMock;

use SockJS::Session;

subtest 'write correct message' => sub {
    my $conn = _mock_conn();
    my $session = _build_session(conn => $conn);

    $session->write('foobar');

    my ($written) = $conn->mocked_call_args('write');
    is $written, 'a["foobar"]';
};

subtest 'custom key values' => sub {
    my $session = _build_session();

    $session->set(foo => 'bar');

    is $session->get('foo'), 'bar';
};

done_testing;

sub _mock_conn {
    my $conn = Test::MonkeyMock->new;
    $conn->mock(close => sub {});
    $conn->mock(write => sub {});

    return $conn;
}

sub _build_session
{
    my (%params) = @_;

    my $conn = delete $params{conn} || _mock_conn();

    SockJS::Session->new(connection => $conn, @_);
}
