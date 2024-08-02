#!/usr/bin/env perl

use PerlLib::SwissArmyKnife;

my $data = DeDumperFile('results.dat');
foreach my $entry (sort {$a->{Name} cmp $b->{Name}} @$data) {
  print $entry->{Name}."\n";
  foreach my $cat (@{$entry->{EstimatedCats}}) {
    print "\t$cat\n";
  }
  print "\n";
}
