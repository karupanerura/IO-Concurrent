package IO::Concurrent::Context;
use strict;
use warnings;

sub new {
    my ($class, $handler, $actors) = @_;
    return bless {
        handler => $handler,
        phase   => 0,
        actors  => $actors,
        error   => undef,
    }, $class;
}

sub handler { shift->{handler} }
sub error   { shift->{error}   }

sub complete     { shift->{completed} = 1 }
sub is_completed { shift->{completed} }

sub abort {
    my ($self, $err) = @_;
    $self->{error} = $err;
    $self->{completed} = 1;
}

sub next :method { shift->{phase}++ }
sub back { shift->{phase}-- }

sub current_actor { $_[0]->{actors}->[$_[0]->{phase}] }

1;
__END__
