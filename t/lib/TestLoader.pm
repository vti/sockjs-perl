package TestLoader;

use strict;
use warnings;

use base 'Test::Class::Load';

sub is_test_class {
    my ($class, $file, $dir) = @_;

    return $file =~ m{Test\.pm\z};
}

1;
