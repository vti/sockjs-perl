requires 'IO::String';
requires 'Plack';
requires 'JSON';
requires 'AnyEvent';
requires 'Protocol::WebSocket';
requires 'IO::Compress::Deflate';

on 'test' => sub {
    requires 'Test::More';
    requires 'Test::Fatal';
    requires 'Test::MonkeyMock';
};
