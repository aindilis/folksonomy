#!/usr/bin/perl -w

use PerlLib::MySQL;

use Data::Dumper;

my $mysql = PerlLib::MySQL->new
  (DBName => "folksonomy");

print Dumper($mysql->Quote("test"));
