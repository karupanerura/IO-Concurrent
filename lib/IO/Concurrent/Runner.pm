package IO::Concurrent::Runner;
use strict;
use warnings;

use IO::Concurrent::Runner::Select;

use Module::Load ();

sub engine {
    my (undef, $name) = @_;
    my $class = 'IO::Concurrent::Runner::'.$name;
    Module::Load::load($class);
    return $class;
}

1;
__END__
