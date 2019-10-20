package IO::Concurrent::Scenario;
use strict;
use warnings;

use Carp ();

use IO::Concurrent::Context;
use IO::Concurrent::Actor;

sub new {
    my ($class) = @_;
    return bless {
        state    => undef,
        actors   => [],
        on_error => sub { Carp::croak(shift->error) },
    }, $class;
}

sub wait_for_writable {
    my ($self, $callback) = @_;
    my $actor = IO::Concurrent::Actor->new(writable => $callback);
    push @{ $self->{actors} } => $actor;
    return $self;
}

sub wait_for_readable {
    my ($self, $callback) = @_;
    my $actor = IO::Concurrent::Actor->new(readable => $callback);
    push @{ $self->{actors} } => $actor;
    return $self;
}

sub on_error {
    my ($self, $callback) = @_;
    $self->{on_error} = $callback if @_ == 2;
    return $self->{on_error};
}

sub create_context {
    my ($self, $handler) = @_;

    my @actors = @{ $self->{actors} };
    return IO::Concurrent::Context->new($handler, \@actors);
}

1;
__END__
