package SockJS;

use strict;
use warnings;

our $VERSION = '0.01';

use overload '&{}' => sub { shift->to_app(@_) }, fallback => 1;

use JSON         ();
use Digest::MD5  ();
use Scalar::Util ();

use Plack::Middleware::Chunked;
use SockJS::Middleware::Http10;
use SockJS::Middleware::JSessionID;
use SockJS::Transport;
use SockJS::Session;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{handler} = $params{handler};

    $self->{websocket}       = $params{websocket};
    $self->{cookie}          = $params{cookie};
    $self->{chunked}         = $params{chunked};
    $self->{sockjs_url}      = $params{sockjs_url};
    $self->{session_factory} = $params{session_factory};

    $self->{websocket} = 1 unless defined $params{websocket};
    $self->{chunked}   = 1 unless defined $params{chunked};
    $self->{sockjs_url} ||= 'http://cdn.sockjs.org/sockjs-0.3.2.min.js';
    $self->{session_factory} ||= sub { SockJS::Session->new };

    $self->{sessions} = {};

    return $self;
}

sub to_app {
    my $self = shift;

    my $app = sub { $self->call(@_) };

    $app = SockJS::Middleware::Http10->new->wrap($app);
    $app = Plack::Middleware::Chunked->new->wrap($app) if $self->{chunked};
    $app =
      SockJS::Middleware::JSessionID->new(cookie => $self->{cookie})
      ->wrap($app);

    return $app;
}

sub call {
    my $self = shift;
    my ($env) = @_;

    my $path_info = $env->{PATH_INFO};
    $path_info = '' unless defined $path_info;

    if ($path_info eq '' || $path_info eq '/') {
        return $self->_dispatch_welcome_page($env);
    }
    elsif ($path_info =~ m{^/[^\/\.]+/([^\/\.]+)/([^\/\.]+)$}) {
        my ($session_id, $transport) = ($1, $2);

        return $self->_dispatch_transport($env, $session_id, $transport);
    }
    elsif ($path_info eq '/info') {
        return $self->_dispatch_info($env);
    }
    elsif ($path_info =~ m{^/iframe[^\/]*\.html$}) {
        return $self->_dispatch_iframe($env);
    }

    return [404, [], ['Not found']];
}

sub _dispatch_welcome_page {
    my $self = shift;
    my ($env) = @_;

    return [
        200, ['Content-Type' => 'text/plain; charset=UTF-8',],
        ["Welcome to SockJS!\n"]
    ];
}

sub _dispatch_transport {
    my $self = shift;
    my ($env, $id, $path) = @_;

    my $transport =
      SockJS::Transport->build($path,
        response_limit => $self->{response_limit});
    return [404, ['Content-Type' => 'text/plain'], ['Not found']]
      unless $transport;

    $env->{'sockjs.transport'} = $transport->name;

    my $session = $self->{sessions}->{$id};

    if (!$session || $transport->name eq 'websocket') {
        $session = $self->{session_factory}->($self);

        if ($transport->name eq 'websocket') {
            push @{$self->{sessions}->{$id}}, $session;
        }
        else {
            $self->{sessions}->{$id} = $session;
        }

        $session->on(
            connected => sub {
                my $session = shift;

                $self->{handler}->($session);
            }
        );

        $session->on(
            aborted => sub {
                my $session = shift;

                if (ref $self->{sessions}->{$id} eq 'ARRAY') {
                    $self->{sessions}->{$id} =
                      [grep { "$_" ne "$session" } @{$self->{sessions}->{$id}}];
                    delete $self->{sessions}->{$id}
                      unless @{$self->{sessions}->{$id}};
                }
                else {
                    delete $self->{sessions}->{$id};
                }
            }
        );
    }

    my $response;
    eval { $response = $transport->dispatch($env, $session, $path) } || do {
        my $e = $@;

        warn $e;

        my ($code, $error) = (500, $e);

        if (Scalar::Util::blessed($e)) {
            $code  = $e->code;
            $error = $e->message;
        }

        $response = [$code, [], [$error]];
    };

    return $response;
}

sub _dispatch_info {
    my $self = shift;
    my ($env) = @_;

    my $origin = $env->{HTTP_ORIGIN};

    my @cors_headers = (
        'Access-Control-Allow-Origin' => !$origin
          || $origin eq 'null' ? '*' : $origin,
        'Access-Control-Allow-Credentials' => 'true'
    );

    if ($env->{REQUEST_METHOD} eq 'OPTIONS') {
        return [
            204,
            [
                'Expires'                      => '31536000',
                'Cache-Control'                => 'public;max-age=31536000',
                'Access-Control-Allow-Methods' => 'OPTIONS, GET',
                'Access-Control-Max-Age'       => '31536000',
                @cors_headers
            ],
            []
        ];
    }

    my $info = JSON::encode_json(
        {
              websocket => $self->{websocket} ? JSON::true
            : JSON::false,
            cookie_needed => $self->{cookie} ? JSON::true
            : JSON::false,
            origins => ['*:*'],
            entropy => int(rand(2**32))
        }
    );

    return [
        200,
        [
            'Content-Type'  => 'application/json; charset=UTF-8',
            'Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0',
            'Access-Control-Allow-Headers' => 'origin, content-type',
            @cors_headers
        ],
        [$info]
    ];
}

sub _dispatch_iframe {
    my $self = shift;
    my ($env) = @_;

    my $sockjs_url = $self->{sockjs_url};
    my $body       = <<"EOF";
<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <script>
    document.domain = document.domain;
    _sockjs_onload = function(){SockJS.bootstrap_iframe();};
  </script>
  <script src="$sockjs_url"></script>
</head>
<body>
  <h2>Don't panic!</h2>
  <p>This is a SockJS hidden iframe. It's used for cross domain magic.</p>
</body>
</html>
EOF

    my $etag = Digest::MD5::md5_hex($body);

    if (my $expected = $env->{HTTP_IF_NONE_MATCH}) {
        if ($expected eq $etag) {
            return [304, [], ['']];
        }
    }

    my $origin       = $env->{HTTP_ORIGIN};
    my @cors_headers = (
        'Access-Control-Allow-Origin' => !$origin
          || $origin eq 'null' ? '*' : $origin,
        'Access-Control-Allow-Credentials' => 'true'
    );
    return [
        200,
        [
            'Content-Type'  => 'text/html; charset=UTF-8',
            'Expires'       => '31536000',
            'Cache-Control' => 'public;max-age=31536000',
            'Etag'          => Digest::MD5::md5_hex($body),
            @cors_headers
        ],
        [$body]
    ];
}

1;
__END__

=head1 NAME

SockJS - SockJS Perl implementation

=head1 SYNOPSIS

    use Plack::Builder;
    use SockJS;

    builder {
        mount '/echo' => SockJS->new(
            handler => sub {
                my ($session) = @_;

                $session->on(
                    'data' => sub {
                        my $session = shift;

                        $session->write(@_);
                    }
                );
            };
        );
    };

=head1 DESCRIPTION

L<SockJS> is a Perl implementation of L<http://sockjs.org>.

=head1 WARNINGS

When using L<Twiggy> there is no chunked support, thus try my fork
L<http://github.com/vti/Twiggy>.

=head1 EXAMPLE

See C<example/> directory.

=head1 DEVELOPMENT

=head2 Repository

    http://github.com/vti/sockjs-perl

=head1 CREDITS

=head1 AUTHOR

Viacheslav Tykhanovskyi, C<vti@cpan.org>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013, Viacheslav Tykhanovskyi

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
