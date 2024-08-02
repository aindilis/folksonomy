package Folksonomy::Target::GHTorrent;

use PerlLib::SwissArmyKnife;

use Text::CSV;
use Try::Tiny;

use AI::Categorizer::Document;
use Data::Dumper;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw { Results MyCSV FH I }

  ];

sub init {
  my ($self,%args) = @_;
}

sub GetUnlabelledData {
  my ($self,%args) = @_;
  $self->I(0);

  my $file = '<REDACTED>/mysql-2018-07-01/projects.csv';
  my @rows;
  my $csv = Text::CSV_XS->new
    ({
      sep_char => ",",
      binary => 1,
      allow_loose_quotes => 1,
     });
  open my $fh, "<", $file or die "$file: $!";
  try {
    my $row = $self->MyCSV->getline( $self->FH );
  } catch {return 1};
  $self->MyCSV($csv);
  $self->FH($fh);
}

sub HasNext {
  my ($self,%args) = @_;
  return 1;
}

sub GetNext {
  my ($self,%args) = @_;
  try {
    my $row = $self->MyCSV->getline( $self->FH );
    my $url = $row->[1];
    my $projectname = $url;
    $projectname =~ s/^https:\/\/api.github.com\/repos\///;
    my $content = $row->[4];
    my $row2 = [$projectname,$content];
    push @rows, $row2;
    print "<$projectname>\n";
    next if $projectname eq '\N';
    my $name = $projectname."#".$self->I;
    $self->I($self->I + 1);
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
  } catch {return 1};
}

1;
