package TestBase;

use strict;
use warnings;

# To be able to run single test classes
INIT { Test::Class->runtests unless $ENV{TEST_SUITE} }

use base 'Test::Class';

sub startup : Test(startup) {
}

sub shutdown : Test(shutdown) {
}

1;
