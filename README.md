[![Build Status](https://travis-ci.org/vti/sockjs-perl.svg?branch=master)](https://travis-ci.org/vti/sockjs-perl) [![MetaCPAN Release](https://badge.fury.io/pl/SockJS.svg)](https://metacpan.org/release/SockJS) [![Kritika Status](https://kritika.io/users/vti/repos/vti+sockjs-perl/heads/master/status.svg)](https://kritika.io/users/vti/repos/vti+sockjs-perl) [![Kritika Status](https://kritika.io/users/vti/repos/vti+sockjs-perl/heads/master/status.svg?type=coverage)](https://kritika.io/users/vti/repos/vti+sockjs-perl) [![Kritika Status](https://kritika.io/users/vti/repos/vti+sockjs-perl/heads/master/status.svg?type=deps)](https://kritika.io/users/vti/repos/vti+sockjs-perl)
# NAME

SockJS - SockJS Perl implementation

# SYNOPSIS

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

# DESCRIPTION

[SockJS](https://metacpan.org/pod/SockJS) is a Perl implementation of [http://sockjs.org](http://sockjs.org).

# WARNINGS

When using [Twiggy](https://metacpan.org/pod/Twiggy) there is no chunked support, thus try my fork
[http://github.com/vti/Twiggy](http://github.com/vti/Twiggy).

# EXAMPLE

See `example/` directory.

# DEVELOPMENT

## Repository

    http://github.com/vti/sockjs-perl

# CREDITS

Matthew Lien (github/BlueT)

Mohammad S Anwar (github/manwar)

# AUTHOR

Viacheslav Tykhanovskyi, `vti@cpan.org`.

# COPYRIGHT AND LICENSE

Copyright (C) 2013-2018, Viacheslav Tykhanovskyi

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.
