# NAME

IO::Concurrent - Concurrent I/O framework

# SYNOPSIS

     use IO::Concurrent;
     use IO::Concurrent::Scenario;

     my @handlers = map {
        $_->blocking(0); # should be non-blocking mode
        $_;
     } ($fh1, $fh2, ...);

    my %items_map;
    IO::Concurrent->new(
        handlers => \@handlers,
    )->run(
        IO::Concurrent::Scenario->new->wait_for_writable(sub {
           my $context = shift;

           $context->handler->syswrite("stats items\r\n");
           $context->next();
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

     my %items_map;
     IO::Concurrent->new(
         handlers => \@handlers,
     )->run(
        IO::Concurrent::Scenario->new->wait_for_writable(sub {
            my $context = shift;
            $context->handler->write("stats items\r\n");
            $context->next();
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
                }

                $context->abort("Invalid payload: $line");
            }
            $context->abort('Assertion failuer: terminator payload "END" has not come, but it EOF received');
        })->wait_for_writable(sub {
            my $context = shift;

            my $items_for_target = $items_map{$context->handler->fileno};
            my ($target_bucket) = keys %$items_for_target; # fetch one bucket id
            my $bucket_items = delete $items_for_target->{$target_bucket};

            $context->handler->write("stats cachedump $target_bucket $bucket_items\r\n");
            $context->next();
        })->wait_for_readable(sub {
            my $context = shift;

            my $items_for_target = $items_map{$context->handler->fileno};
            while (my $line = $context->handler->getline()) {
                $line =~ s/\r\n$//; # chomp

                if ($line eq 'END') {
                    my $has_more = keys %$items_for_target;
                    if ($has_more) {
                        $context->back();
                    } else {
                        $context->next();
                    }
                    return;
                } elsif ($line =~ /^ITEM (\S+) \[.* (\d+) s\]/) {
                    my ($key, $expires) = @_;
                    print "key:$key\texpires:$expires\n";
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

# DESCRIPTION

IO::Concurrent is a concurrent I/O framework.

When implements concurrent non-blocking I/O using `select(2)` or others (without [AnyEvent](https://metacpan.org/pod/AnyEvent)/[IO::AIO](https://metacpan.org/pod/IO::AIO)), it makes many complex procedural codes.
This framework makes easy to write it by scenarios.

# LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

karupanerura <karupa@cpan.org>
