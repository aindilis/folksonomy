package Folksonomy;

# this is an adaptation of the auto-debtags script to index the
# contents of sourceforge and freshmeat as well

use BOSS::Config;
use MyFRDCSA;
use PerlLib::MySQL;
use PerlLib::SwissArmyKnife;

use AI::Categorizer;
use AI::Categorizer::Learner::NaiveBayes;
use AI::Categorizer::Learner::SVM;
use Data::Dumper;
use IO::File;
use MIME::Base64;

my $specification = "
	--source <source>	Choose source (i.e. the training set) : Debtags, Freshmeat or Sourceforge
	--target <target>	Choose target (i.e. the testing set) : Apt, CSO
	--learner <type>	Select the learner type : SVM, NaiveBayes

	--formats <format>...	Choose the formats of the text presented to the learner and classified
	--folksonomies <folksonomy>...	Choose the category systems to be learned (specific to a source)

	# --filters <filter>...	Choose Filters to be used (specific to a target)

	--model <model>		Model directory if any

	--tiny			Use barely any systems

	--to-text		Save to text instead of the DB
	# --traintest <percentage>	Do a traintest on the source only, using percentage documents for training
";

my $config = BOSS::Config->new
  (Spec => $specification,
   ConfFile => "");
my $conf = $config->CLIConfig;
$UNIVERSAL::systemdir = ConcatDir(Dir("minor codebases"),"folksonomy");

die "No sources\n" unless exists $conf->{'--source'};
die "No target\n" unless exists $conf->{'--target'};
die "No learner\n" unless exists $conf->{'--learner'};

my $formats = "";
if (exists $conf->{'--formats'}) {
  $elements = "--".join("-",sort @{$conf->{'--formats'}});
}
my $folksonomies = "";
if (exists $conf->{'--folksonomies'}) {
  $elements = "--".join("-",sort @{$conf->{'--folksonomies'}});
}
# my $identifier = "folk-".$conf->{'--source'}."-".$conf->{'--target'}."-".$conf->{'--learner'}.$formats.$folksonomies;
my $identifier = "folk-".$conf->{'--source'}."-"."CSO"."-".$conf->{'--learner'}.$formats.$folksonomies;
my $statepath;
if (exists $conf->{'--model'}) {
  $statepath = $conf->{'--model'};
} else {
  if (exists $conf->{'--target'} and exists $conf->{'--learner'}) {
    $statepath = "$UNIVERSAL::systemdir/data/models/$identifier";
  } else {
    $statepath = undef;
  }
}

# Create the Learner, and restore state if need be
my $learner;
my $needstraining;
if (exists $conf->{'--learner'}) {
  if ($conf->{'--learner'} eq "SVM") {
    if (-d $statepath) {
      print "Restoring state\n";
      $learner = AI::Categorizer::Learner::SVM->restore_state($statepath);
    } else {
      $learner = AI::Categorizer::Learner::SVM->new();
      $needstraining = 1;
    }
  } elsif ($conf->{'--learner'} eq "NaiveBayes") {
    if (-d $statepath) {
      print "Restoring state\n";
      $learner = AI::Categorizer::Learner::NaiveBayes->restore_state($statepath);
    } else {
      $learner = AI::Categorizer::Learner::NaiveBayes->new();
      $needstraining = 1;
    }
  } else {
    die "Learner ".$conf->{'--learner'}." not found\n";
  }
}

if ($needstraining) {
  # LOAD THE SOURCE DATA
  my $src = $conf->{'--source'};
  my $srcfile = "$UNIVERSAL::systemdir/Folksonomy/Source/$src.pm";
  if (-f $srcfile) {
    require $srcfile;
  } else {
    die "No such sourcefile exists: $srcfile\n";
  }
  my $source = "Folksonomy::Source::$src"->new
    (
     Elements => $conf->{'--elements'},
    );
  my $retval = $source->GetTrainingData
    (
     Tiny => $conf->{'--tiny'},
    );
  my $categories = $retval->{Categories};
  my $results = $retval->{Results};

  # CREATE CATEGORIES
  my @categorynames = keys %$categories;
  my @categories;
  my %mycategories;
  foreach my $categoryname (@categorynames) {
    my $cat = AI::Categorizer::Category->by_name(name => $categoryname);
    $mycategories{$categoryname} = $cat;
    push @categories, $cat;
  }

  # load "documents"
  # randomly add documents to both the categories and knowledge sets
  my @documents;
  my @test;
  my @train;

  my $traincutoff;
  if (exists $conf->{'--traintest'}) {
    print "Doing a train test\n";
    $percentage = $conf->{'--traintest'};
    die "Invalid percentage: $percentage\n" unless ($percentage >= 0 and $percentage <= 100);
  }

  my $i = 0;
  foreach my $key (keys %$results) {
    if (! ($i % 100)) {
      print $i."\n";
    }
    ++$i;
    push @documents, $d;
    if (defined $percentage and int(rand(100)) > $percentage) {
      my $d = AI::Categorizer::Document->new
	(name => $results->{$key}->{ID},
	 content => $results->{$key}->{Contents});
      push @test, $d;
#     } else {
#       # add $d to a random category  << What the heck is this all about?
#       my $category = $categories[int(rand(scalar @categories))];
#       my $d = AI::Categorizer::Document->new
# 	(name => $results->{$key}->{ID},
# 	 content => $results->{$key}->{Contents},
# 	 categories => $results->{$key}->{Categories});
#       $category->add_document($d);
#       push @train, $d;
    } else {
      my $d = AI::Categorizer::Document->new
	(name => $results->{$key}->{ID},
	 content => $results->{$key}->{Contents},
	 categories => $results->{$key}->{Categories});
      my $hash = $results->{$key}->{Categories};
      my $type = ref($hash);
      if ($type eq 'HASHREF') {
	foreach my $catname (keys %{$hash}) {
	  $mycategories{$catname}->add_document($d);
	}
      }
      push @train, $d;
    }
  }

  # create a knowledge set
  my $k = new AI::Categorizer::KnowledgeSet
    (categories => \@categories,
     documents => \@train);

  print "Training, this could take some time...\n";
  $learner->train(knowledge_set => $k);
  $learner->save_state($statepath) if $statepath;
}

# LOAD TARGET
my $tgt = $conf->{'--target'};
my $tgtfile = "$UNIVERSAL::systemdir/Folksonomy/Target/$tgt.pm";
if (-f $tgtfile) {
  require $tgtfile;
} else {
  die "No such tgtfile exists: $tgtfile\n";
}
my $target = "Folksonomy::Target::$tgt"->new
  (
   Filters => $conf->{'--filters'},
  );
$target->GetUnlabelledData
  (
   Tiny => $conf->{'--tiny'},
  );


# CATEGORIZE AND SAVE RESULTS
my $mysql = PerlLib::MySQL->new
  (DBName => 'folksonomy');
if (exists $conf->{'--to-text'}) {
  my $fn = "$UNIVERSAL::systemdir/data/results/$identifier";
  if (! -f $fn) {
    mkdir $fn;
  }
}
my $catids = {};
my $nameids = {};
my $runid = GetRunID;
while ($target->HasNext) {
  my $item = $target->GetNext;
  Categorize(Item => $item) if defined $item;
}

sub Categorize {
  my %args = @_;
  my $d = $args{Item}->{D};
  # check whether this has already been categorized
  next unless defined $d;
  my $name = $d->name;
  my $encoded = encode_base64($name);
  my $fn = "$UNIVERSAL::systemdir/data/results/$identifier/$encoded";
  my $needscategorization = 0;
  my $answer;
  if (exists $conf->{'--to-text'}) {
    if (-f $fn) {
      # $answer = stuff
    }
  } else {
    if (0) {
      # $answer = stuff
    }
  }
  if (! defined $answer) {
    my $hypothesis = $learner->categorize($d);
    my $cats = $args{Item}->{Categories};
    $answer = {
	       Name => $name,
	       Contents => $args{Item}->{Contents},
	       EstimatedCats => [$hypothesis->categories],
	       ActualCats => [map {$_->name} @$cats],
	      };
    if (exists $conf->{'--to-text'}) {
      $fh = new IO::File ">$fn";
      if (defined $fh) {
	print $fh Dumper($answer);
	$fh->close;
      }
    } else {
      WriteToDB($answer);
    }
  }
  # now we have the answer!
  # what to do with it...
  print Dumper($answer);
}

sub WriteToDB {
  # now we add this to the database
  my $answer = shift;
  my $nameid = GetNameID($answer->{Name});
  # first retrieve all the instances of the cats
  my $cats = $answer->{EstimatedCats};
  my $count = scalar @$cats;
  $mysql->Do
    (Statement => "insert into count values ('$runid', '$nameid', '$count')");
  foreach my $cat (@$cats) {
    my $tagid = GetCatID($cat);
    $mysql->Do
      (Statement => "insert into entries values (NULL, '$runid', '$nameid', '$tagid')");
  }
}

sub GetRunID {
  my $quotedsource = $mysql->Quote($conf->{'--source'});
  my $quotedtarget = $mysql->Quote($conf->{'--target'});
  my $quotedlearner = $mysql->Quote($conf->{'--learner'});
  $mysql->Do
    (Statement => "insert into runs values (NULL,$quotedsource,$quotedtarget,$quotedlearner,NOW())");
  return $mysql->InsertID(Table => "runs");
}

sub GetNameID {
  my $name = shift;
  if (! exists $nameids->{$name}) {
    my $quotedname = $mysql->Quote($name);
    my $res = $mysql->Do
      (Statement => "select * from names where Name=$quotedname");
    if (keys %$res) {
      foreach my $key (keys %$res) {
	$nameids->{$name} = $key;
      }
    } else {
      my $res2 = $mysql->Do
	(Statement => "insert into names values (NULL,$quotedname)");
      $nameids->{$name} = $mysql->InsertID(Table => "names");
    }
  }
  return $nameids->{$name};
}

sub GetCatID {
  my $cat = shift;
  if (! exists $catids->{$cat}) {
    my $quotedtag = $mysql->Quote($cat);
    my $res = $mysql->Do
      (Statement => "select * from tags where Tag=$quotedtag");
    if (keys %$res) {
      foreach my $key (keys %$res) {
	$catids->{$cat} = $key;
      }
    } else {
      my $res2 = $mysql->Do
	(Statement => "insert into tags values (NULL,$quotedtag)");
      $catids->{$cat} = $mysql->InsertID(Table => "tags");
    }
  }
  return $catids->{$cat};
}

1;
