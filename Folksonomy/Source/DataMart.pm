package Folksonomy::Source::DataMart;

use Data::Dumper;
use IO::File;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw { FH }

  ];

sub init {
  my ($self,%args) = @_;
}

sub Update {
  my ($self,%args) = @_;
  
}

sub GetTrainingData {
  my ($self,%args) = @_;
  # this is where we determine what to do
  my $categories = {};
  my $results = {};

  # what we are taking as input

  # what category system we are learning

  # okay we need to do this for various systems

  # possibly folksonomies
  # topic, programming_language, status, 

  my $closed;
  my @packages = $self->GetAllPackages();
  while (@packages) {
    $res = shift @packages;
    my %package = %{$res->{Parsed}};
    last unless (defined $res->{All} and scalar values %package);
    my @catnames;
    next if ! defined $package{Tag};
    foreach my $cat (split /, /,$package{Tag}) {
      # now split this cat
      if ($cat =~ /^(.+)\{([^\}]+)\}$/) {
	# handle the case of things like: devel::{lang:c,lang:c++,lang:r}
	my $prefix = $1;
	my $items = $2;
	foreach my $item (split /,/,$items) {
	  push @catnames, "$prefix$item";
	}
      } else {
	push @catnames, $cat;
      }
    }
    my @cats;
    foreach my $name (@catnames) {
      if (! exists $categories->{$name}) {
	print $name."\n";
	$categories->{$name} = AI::Categorizer::Category->by_name(name => $name);
      }
      push @cats, $categories->{$name};
    }
    $results->{$package{Package}} = {
				     ID => $package{Package},
				     Contents => $package{body}, # $res->{All},
				     Categories => \@cats,
				    };
  }
  return {
	  Categories => $categories,
	  Results => $results,
	 };
}

sub GetAllPackages {
  my ($self) = @_;
  my @packages;
  while (! $closed) {
    push @packages, $self->GetNextPackage();
  }
  return @packages;
}

sub GetNextPackage {
  my ($self) = @_;
  my %parsed;
  my $all;
  my $last = 0;
  my $fh = $self->FH;
  while (<$fh>) {
    if (/^$/) {
      $last = 1;
      last;
    }
    if (my ($key, $value) = m/^(.*): (.*)/) {
      $parsed{$key} = $value;
      if ($key ne "Tag") {
	$all .= $_;
      }
    } else {
      s/ //;
      s/^\.$//;
      $parsed{body} .= $_;
      $all .= $_;
    }
  }
  if (! $last) {
    $closed = 1;
  }
  return {
	  Parsed => \%parsed,
	  All => $all,
	 };
}

1;
