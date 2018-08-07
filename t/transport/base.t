use strict;
use warnings;

use Test::More;

use SockJS::Transport::Base;

subtest 'set name' => sub {
    my $transport = _build_transport(name => 'foo');

    is $transport->name, 'foo';
};

subtest 'return error when method not allowed' => sub {
    my $transport = _build_transport();

    my $res = $transport->dispatch({REQUEST_METHOD => 'FOO'});

    is_deeply $res, [405, ['Allow' => 'OPTIONS, GET'], ['']];
};

subtest 'dispatch options' => sub {
    my $transport = _build_transport();

    my $res = $transport->dispatch({REQUEST_METHOD => 'OPTIONS'});

    is_deeply $res, [ 204, [], [''] ];
};

subtest 'dispatch allowed method' => sub {
    my $transport = _build_transport();

    my $res = $transport->dispatch({REQUEST_METHOD => 'GET'});

    is_deeply $res, [200, [], ['OK']];
};

done_testing;

sub _build_transport
{
    Test::SockJS::Transport::Dummy->new(@_);
}

package Test::SockJS::Transport::Dummy;
use base 'SockJS::Transport::Base';

sub new {
    my $self = shift->SUPER::new(@_);

    push @{$self->{allowed_methods}}, 'GET';

    return $self;
}

sub dispatch_GET {[200, [], ['OK']]}
