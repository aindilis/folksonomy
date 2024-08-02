package Folksonomy::Target::Datamart;

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
  my $mysql = PerlLib::MySQL->new
    (DBName => "cso");
  print "Loading CSO\n";
  $self->Results
    ($mysql->Do
     (Statement => "select * from systems where Source='SF(20071001)' or Source='FM(20071101)'",
      KeyField => "ID"));
  $self->Keys
    ([keys %{$self->Results}]);
}

sub HasNext {
  my ($self,%args) = @_;
  return scalar @{$self->Keys} > 0;
}

sub GetNext {
  my ($self,%args) = @_;
  my $key = shift @{$self->Keys};
  my $name = $self->Results->{$key}->{Name}."#".$self->Results->{$key}->{ID};
  my $content;
  $content .= $self->Results->{$key}->{ShortDesc} if defined $self->Results->{$key}->{ShortDesc};
  $content .= $self->Results->{$key}->{LongDesc} if defined $self->Results->{$key}->{LongDesc};
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
