package IO::Concurrent::Runner;
use strict;
use warnings;

use IO::Select;

use Carp ();
$Carp::Internal{+__PACKAGE__}++;

sub new {
    my ($class, $contexts, $opts) = @_;
    $opts ||= {};

    bless {
        %$opts,
        contexts => $contexts,
    } => $class;
}

sub run {
    my $self = shift;

    my %context_map = map { $_->handler->fileno => $_ } @{ $self->{contexts} };

    my @aborted_contexts;
    while (%context_map) {
        my ($readable, $writable) = do {
            my @readers = map { $_->handler } grep { $_->current_actor->is_waiting_for_readable } values %context_map;
            my @writers = map { $_->handler } grep { $_->current_actor->is_waiting_for_writable } values %context_map;
            IO::Select->select(
                IO::Select->new(@readers),
                IO::Select->new(@writers),
                undef,
                0
            )
        };

        if (defined $writable) {
            my @writable_context = @context_map{map $_->fileno, @$writable};
            for my $context (@writable_context) {
                $context->current_actor->callback->($context);
                push @aborted_contexts => $context if $context->error;
                delete $context_map{$context->handler->fileno} if $context->is_completed;
            }
        }

        if (defined $readable) {
            my @readable_context = @context_map{map $_->fileno, @$readable};
            for my $context (@readable_context) {
                $context->current_actor->callback->($context);
                push @aborted_contexts => $context if $context->error;
                delete $context_map{$context->handler->fileno} if $context->is_completed;
            }
        }
    }

    for my $context (@aborted_contexts) {
        $self->{on_error}->($context);
    }
}

1;
__END__
