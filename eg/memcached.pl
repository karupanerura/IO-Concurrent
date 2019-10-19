use strict;
use warnings;

use IO::Socket::INET;

use IO::Concurrent;
use IO::Concurrent::Scenario;

my @handlers;
for my $addr (@ARGV) {
    my $sock = IO::Socket::INET->new(
        PeerAddr  => $addr,
        Proto     => 'tcp',
        ReuseAddr => 1,
        Timeout   => 5,
        Blocking  => 0,
    ) or die "$!: $addr";
    push @handlers => $sock;
}

my %items_map;
IO::Concurrent->new(
    handlers => \@handlers,
)->run(
    IO::Concurrent::Scenario->new->wait_for_writable(sub {
       my $context = shift;

       $context->handler->syswrite("stats items\r\n");
       $context->next;
    })->wait_for_readable(sub {
       my $context = shift;

       my $items_for_target = ($items_map{$context->handler->fileno} ||= {});
       while (my $line = $context->handler->getline()) {
           $line =~ s/\r\n$//; # chomp

           if ($line eq 'END') {
               $context->next();
               return;
           } elsif ($line =~ /^STAT items:(\d*):number (\d*)/) {
               $items_for_target->{$1} = $2;
               next;
           }

           # ignore others
       }
       $context->abort('Assertion failuer: terminator payload "END" has not come, but it EOF received');
   })->wait_for_writable(sub {
       my $context = shift;

       my $items_for_target = $items_map{$context->handler->fileno};
       my ($target_bucket) = keys %$items_for_target; # fetch one bucket id
       unless ($target_bucket) {
           $context->complete();
           return;
       }

       my $bucket_items = delete $items_for_target->{$target_bucket};

       $context->handler->syswrite("stats cachedump $target_bucket $bucket_items\r\n");
       $context->next();
   })->wait_for_readable(sub {
       my $context = shift;

       my $items_for_target = $items_map{$context->handler->fileno};
       while (my $line = $context->handler->getline()) {
           $line =~ s/\r\n$//; # chomp

           if ($line eq 'END') {
               my $has_more = keys %$items_for_target;
               if (defined $has_more) {
                   $context->back();
               } else {
                   $context->next();
               }
               return;
           } elsif ($line =~ /^ITEM (\S+) \[.* (\d+) s\]/) {
               my ($key, $expires) = ($1, $2);
               print "key:$key\texpires:$expires\n";
               next;
           }

           $context->abort("Invalid payload: $line");
       }
       $context->abort('Assertion failuer: terminator payload "END" has not come, but it EOF received');
   })->wait_for_writable(sub {
       my $context = shift;

       $context->handler->blocking(1);
       $context->handler->write("quit\r\n");
       $context->handler->close();
   })
);
