package SockJS::Session;

use strict;
use warnings;

use JSON ();
use Encode ();

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{id}   = $params{id};
    $self->{type} = $params{type};
    $self->{conn} = $params{connection};

    return $self;
}

sub set {
    my $self = shift;
    my ($key, $value) = @_;

    $self->{custom}->{$key} = $value;

    return $self;
}

sub get {
    my $self = shift;
    my ($key) = @_;

    return $self->{custom}->{$key};
}

sub type { $_[0]->{type} }

sub on {
    my $self = shift;
    my ($event, $cb) = @_;

    push @{$self->{"on_$event"}}, $cb;

    return $self;
}

sub write {
    my $self = shift;

    my $message;
    if (ref $_[0] eq 'SCALAR') {
        $message = ${$_[0]};
        $message = Encode::encode('UTF-8', $message) if Encode::is_utf8($message);
    }
    else {
        $message = 'a' . JSON->new->ascii(1)->encode([@_]) if @_;
    }

    return $self->{conn}->write($message);
}

sub close {
    my $self = shift;
    my ($code, $message) = @_;

    $self->{conn}->close($code, $message);

    return $self;
}

sub fire_event {
    my $self  = shift;
    my $event = shift;

    if (exists $self->{"on_$event"}) {
        foreach my $ev (@{$self->{"on_$event"}}) {
            $ev->($self, @_);
        }
    }

    return $self;
}

1;
