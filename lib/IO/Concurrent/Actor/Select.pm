package IO::Concurrent::Actor::Select;
use strict;
use warnings;

use parent qw/IO::Concurrent::Actor/;

use Carp ();

use constant {
    WRITABLE => 'writable',
    READABLE => 'readable',
};

sub type { 'select' }

sub new {
    my ($class, $event_type, $callback) = @_;
    if ($event_type ne WRITABLE && $event_type ne READABLE) {
        Carp::croak("invalid event type: $event_type");
    }

    return bless {
        event_type => $event_type,
        callback   => $callback,
    } => $class;
}

sub is_waiting_for_writable { shift->{event_type} eq WRITABLE }
sub is_waiting_for_readable { shift->{event_type} eq READABLE }

sub callback { shift->{callback} }

1;
__END__
