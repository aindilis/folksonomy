package Folksonomy::Target::InternalAndMinorCodebases;

use MyFRDCSA qw(ConcatDir);
use FWeb2::FRDCSA;
use PerlLib::MySQL;

use AI::Categorizer::Document;
use Data::Dumper;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw { Results Keys }

  ];

sub init {
  my ($self,%args) = @_;
}

sub GetUnlabelledData {
  my ($self,%args) = @_;
  $self->Results({});
  $self->Keys([]);
  my $mysql = PerlLib::MySQL->new
    (DBName => "cso");
  print "Loading InternalAndMinorCodebases\n";
  foreach my $type (qw(internal minor)) {
    my $icodebasedir = "/var/lib/myfrdcsa/codebases/$type";
    foreach my $icodebasename ( split /\n/, `ls -1 $icodebasedir`) {
      my $systemdir = ConcatDir($icodebasedir,$icodebasename);
      if (-d $systemdir) {
	my $frdcsaxmlfile = ConcatDir($systemdir,'frdcsa/FRDCSA.xml');
	if (-f $frdcsaxmlfile) {
	  $self->Results->{$icodebasename} = $frdcsaxmlfile;
	}
      }
    }
  }
  $self->Keys
    ([keys %{$self->Results}]);
  print "Done loading InternalAndMinorCodebases\n";
}

sub HasNext {
  my ($self,%args) = @_;
  return scalar @{$self->Keys} > 0;
}

sub GetNext {
  my ($self,%args) = @_;
  my $name = shift @{$self->Keys};
  my $parsed = FWeb2::FRDCSA->new
    (
     SubsystemDescriptionFile => $self->Results->{$name},
    );
  $parsed->Parse();
  my $content;
  $content .= $parsed->ShortDesc if defined $parsed->ShortDesc;
  $content .= $parsed->LongDesc if defined $parsed->LongDesc;
  if (defined $content) {
    my $d = AI::Categorizer::Document->new
      (name => $name,
       content => $content);
    return {
	    D => $d,
	    Categories => [],
	    Contents => $content,
	   } if defined $d;
  }
}

1;
