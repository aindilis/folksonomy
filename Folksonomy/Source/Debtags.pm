package Folksonomy::Source::Debtags;

use PerlLib::EasyPersist;
use Data::Dumper;
use IO::File;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw { FH MyEasyPersist }

  ];

sub init {
  my ($self,%args) = @_;
}

sub Update {
  my ($self,%args) = @_;
  # use easy persist here
  if (! defined $self->MyEasyPersist) {
    $self->MyEasyPersist(PerlLib::EasyPersist->new);
  }
  #   $self->MyEasyPersist->get
  #     (
  #      Command => "`apt-cache search -f .`",
  #      Overwrite => 1,
  #     );
}

sub GetTrainingData {
  my ($self,%args) = @_;
  # this is where we determine what to do
  my $categories = {};
  my $results = {};

  my $fh;
  if ($args{Tiny}) {
    print "Tiny\n";
    #     my $self->MyEasyPersist->get
    #       (
    #        Command => "`apt-cache search -f .`",
    #       );
    $self->FH(IO::File->new("$UNIVERSAL::systemdir/data/input/example.txt"));
  } else {
    $self->FH(IO::File->new("$UNIVERSAL::systemdir/data/input/all.txt"));
  }
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
