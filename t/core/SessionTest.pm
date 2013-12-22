package SessionTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use SockJS::Session;

sub not_connected : Test {
    my $self = shift;

    my $session = $self->_build_session;

    ok(!$session->is_connected);
}

sub run_connected : Test {
    my $self = shift;

    my $connected;

    my $session = $self->_build_session;
    $session->on('connected', sub { $connected++ });

    $session->connected;

    ok($connected);
}

sub run_syswrite : Test {
    my $self = shift;

    my $written;

    my $session = $self->_build_session;
    $session->on('connected', sub { });
    $session->on('syswrite', sub { $written = $_[1] });

    $session->connected;
    $session->syswrite('foo');

    is($written, 'foo');
}

sub encode_when_writing : Test {
    my $self = shift;

    my $written;

    my $session = $self->_build_session;
    $session->on('connected', sub { });
    $session->on('syswrite', sub { $written = $_[1] });

    $session->connected;
    $session->write('foo');

    is($written, 'a["foo"]');
}

sub stage_messages_when_not_connected : Test(2) {
    my $self = shift;

    my $written;

    my $session = $self->_build_session;
    $session->on('connected', sub { });
    $session->on('syswrite', sub { $written = $_[1] });

    $session->write('foo');

    ok(!$written);

    $session->connected;

    is($written, 'a["foo"]');
}

sub glue_stage_messages : Test {
    my $self = shift;

    my $written = '';

    my $session = $self->_build_session;
    $session->on('connected', sub { });
    $session->on('syswrite', sub { $written .= $_[1] });

    $session->write('foo');
    $session->write('bar');
    $session->write('baz');
    $session->syswrite('c[]');
    $session->write('123');

    $session->connected;

    is($written, 'a["foo","bar","baz"]c[]a["123"]');
}

sub stage_messages_when_reconnecting : Test(2) {
    my $self = shift;

    my $written;

    my $session = $self->_build_session;
    $session->on('connected', sub { });
    $session->on(
        'syswrite',
        sub {
            my $session = shift;
            my ($message) = @_;
            $written = $message;
        }
    );

    $session->connected;
    $session->write('foo');
    $session->reconnecting;

    $session->write('bar');

    is($written, 'a["foo"]');

    $session->reconnected;
    is($written, 'a["bar"]');
}

sub run_closed : Test {
    my $self = shift;

    my $closed;

    my $session = $self->_build_session;
    $session->on('connected', sub { });
    $session->on('syswrite',  sub { });
    $session->on('close',     sub { $closed++ });

    $session->connected;
    $session->close;

    ok($closed);
}

sub print_default_close_message : Test {
    my $self = shift;

    my $written;

    my $session = $self->_build_session;
    $session->on('connected', sub { });
    $session->on('syswrite',  sub { $written = $_[1] });
    $session->on('close',     sub { });

    $session->connected;
    $session->close;

    is($written, 'c[3000,"Get away!"]');
}

sub print_close_message : Test {
    my $self = shift;

    my $written;

    my $session = $self->_build_session;
    $session->on('connected', sub { });
    $session->on('syswrite',  sub { $written = $_[1] });
    $session->on('close',     sub { });

    $session->connected;
    $session->close(1234, 'Bye');

    is($written, 'c[1234,"Bye"]');
}

sub remember_close_message : Test {
    my $self = shift;

    my $written = '';

    my $session = $self->_build_session;
    $session->on('connected', sub { });
    $session->on('syswrite',  sub { $written .= $_[1] });
    $session->on('close',     sub { });

    $session->connected;
    $session->close(1234, 'Bye');
    $session->close;

    is($written, 'c[1234,"Bye"]c[1234,"Bye"]');
}

sub fire_close_event_when_abort_not_set : Test {
    my $self = shift;

    my $written = '';

    my $session = $self->_build_session;
    $session->on('close', sub { $written .= 'close' });

    $session->connected;
    $session->aborted;

    is($written, 'close');
}

sub fire_abort_event_on_aborted : Test {
    my $self = shift;

    my $written = '';

    my $session = $self->_build_session;
    $session->on('close', sub { $written .= 'close' });
    $session->on('abort', sub { $written .= 'abort' });

    $session->connected;
    $session->aborted;

    is($written, 'abort');
}

sub _build_session {
    my $self = shift;

    return SockJS::Session->new(@_);
}

1;
