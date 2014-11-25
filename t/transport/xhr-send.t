use strict;
use warnings;

use Test::More;

use SockJS::Connection;
use SockJS::Transport::XHRSend;

subtest 'return error when not connected' => sub {
    my $transport = _build_transport();

    my $conn = _build_conn();

    my $res = $transport->dispatch({REQUEST_METHOD => 'POST'}, $conn);

    is_deeply $res, [404, [], ['Not found']];
};

subtest 'return error when content length not equals actual read data' => sub {
    my $transport = _build_transport();

    my $conn = _build_conn();

    $conn->connected;

    my $input = 'foobar';
    open my $fh, '<', \$input;

    my $res = $transport->dispatch(
        {REQUEST_METHOD => 'POST', CONTENT_LENGTH => 100, 'psgi.input' => $fh},
        $conn
    );

    is_deeply $res,
      [
        500,
        ['Content-Type', 'text/plain; charset=UTF-8', 'Content-Length' => 12],
        ['System error']
      ];
};

subtest 'return error when no payload' => sub {
    my $transport = _build_transport();

    my $conn = _build_conn();

    $conn->connected;

    my $input = '';
    open my $fh, '<', \$input;

    my $res = $transport->dispatch(
        {REQUEST_METHOD => 'POST', CONTENT_LENGTH => 0, 'psgi.input' => $fh},
        $conn);

    is_deeply $res,
      [
        500, ['Content-Type', 'text/plain; charset=UTF-8', 'Content-Length' => 17],
        ['Payload expected.']
      ];
};

subtest 'return error when broken JSON' => sub {
    my $transport = _build_transport();

    my $conn = _build_conn();

    $conn->connected;

    my $input = '123';
    open my $fh, '<', \$input;

    my $res = $transport->dispatch(
        {REQUEST_METHOD => 'POST', CONTENT_LENGTH => 3, 'psgi.input' => $fh},
        $conn);

    is_deeply $res,
      [
        500, ['Content-Type', 'text/plain; charset=UTF-8', 'Content-Length' => 21],
        ['Broken JSON encoding.']
      ];
};

subtest 'call on data with simple POST' => sub {
    my $transport = _build_transport();

    my $conn = _build_conn();

    my @data;
    $conn->connected;
    $conn->on(data => sub { shift; @data = @_ });

    my $input = '[{"foo":"bar"}]';
    open my $fh, '<', \$input;

    my $res = $transport->dispatch(
        {
            REQUEST_METHOD => 'POST',
            CONTENT_LENGTH => length($input),
            'psgi.input'   => $fh
        },
        $conn
    );

    is_deeply \@data, [{foo => 'bar'}];
};

subtest 'return correct response' => sub {
    my $transport = _build_transport();

    my $conn = _build_conn();

    $conn->connected;

    my $input = '[{"foo":"bar"}]';
    open my $fh, '<', \$input;

    my $res = $transport->dispatch(
        {
            REQUEST_METHOD => 'POST',
            CONTENT_LENGTH => length($input),
            'psgi.input'   => $fh
        },
        $conn
    );

    is_deeply $res,
      [
        204,
        [
            'Content-Type'                 => 'text/plain; charset=UTF-8',
            'Access-Control-Allow-Headers' => 'origin, content-type',
            'Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0',
            'Access-Control-Allow-Origin'      => '*',
            'Access-Control-Allow-Credentials' => 'true',
        ],
        []
      ];
};

done_testing;

sub _build_conn {
    SockJS::Connection->new(@_);
}

sub _build_transport {
    SockJS::Transport::XHRSend->new(@_);
}
