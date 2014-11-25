use strict;
use warnings;

use Test::More;

use SockJS::Connection;

subtest 'call connect event' => sub {
    my $conn = _build_conn();

    my $connected;
    $conn->on(connect => sub { $connected++ });

    $conn->connected;

    ok $connected;
};

subtest 'call close event' => sub {
    my $conn = _build_conn();

    my $closed;
    $conn->on(close => sub { $closed++ });

    $conn->connected;
    $conn->close;

    ok $closed;
};

subtest 'call close when no abort event' => sub {
    my $conn = _build_conn();

    my $closed;
    $conn->on(close => sub { $closed++ });

    $conn->connected;
    $conn->aborted;

    ok $closed;
};

subtest 'call abort event' => sub {
    my $conn = _build_conn();

    my $aborted;
    $conn->on(abort => sub { $aborted++ });

    $conn->connected;
    $conn->aborted;

    ok $aborted;
};

subtest 'not write when not connected' => sub {
    my $conn = _build_conn();

    my $written = '';
    $conn->write_cb(sub { $written .= $_[1] });

    $conn->write('foo');
    $conn->write('bar');

    is $written, '';
};

subtest 'cache messages when not connected' => sub {
    my $conn = _build_conn();

    my $written = '';
    $conn->write_cb(sub { $written .= $_[1] });

    $conn->write('foo');
    $conn->write('bar');

    $conn->connected;

    is $written, 'foobar';
};

subtest 'glue a[] staged messages' => sub {
    my $conn = _build_conn();

    my $written = '';
    $conn->write_cb(sub { $written .= $_[1] });

    $conn->write('a["foo"]');
    $conn->write('a["bar"]');

    $conn->connected;

    is $written, 'a["foo","bar"]';
};

subtest 'cache messages when not reconnected' => sub {
    my $conn = _build_conn();

    my $written = '';
    $conn->write_cb(sub { $written .= $_[1] });

    $conn->connected;

    $conn->reconnecting;

    $conn->write('foo');
    $conn->write('bar');

    $conn->reconnected;

    is $written, 'foobar';
};

done_testing;

sub _build_conn
{
    SockJS::Connection->new(@_);
}
