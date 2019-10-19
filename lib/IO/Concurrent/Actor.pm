package IO::Concurrent::Actor;
use strict;
use warnings;

use Carp ();

sub type     { Carp::croak('abstract method') }
sub callback { Carp::croak('abstract method') }

1;
__END__
