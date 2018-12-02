requires 'IO::String';
requires 'Plack';
requires 'JSON';
requires 'AnyEvent';
requires 'Protocol::WebSocket';
requires 'IO::Compress::Deflate';

# fix security issue https://kritika.io/sa/CPANSA-HTTP-Tiny-2016-01
requires 'HTTP::Tiny', '0.076';

# make sure any() is available
requires 'List::Util', '1.50';

on 'test' => sub {
    requires 'Test::More';
    requires 'Test::Fatal';
    requires 'Test::MonkeyMock';
};
