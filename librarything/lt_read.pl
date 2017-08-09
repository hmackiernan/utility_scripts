#!/usr/local/perl
use strict;
use warnings;
use Getopt::Long;
use IO::File;
use Data::LineBuffer;
use Data::Dumper;
use Date::Manip;
use Cwd;
use English;
use Tie::DBI;

# 1. Export from LibraryThing as 'Tab Delimited' (XLS)
# 2. Open in Excel
# 3. Save as Text for Windows

# config hash (with a few defaults)
my %config = (
	      src_dir => 'Data',	      
	      key_name => 'ISBN',
	      table_name => 'lt_titles',
);

# SQL date format string
my $SQL_FMT  = "%Y-%m-%d %H:%M:%S";

# PHASE 0: COMMAND LINE ARGUMENT MARSHALLING

# If you require more command line arguments, add them here. 
# read the documentation for the Getopt::Long module 
GetOptions(\%config, 'src_dir=s','infile=s', 'table_name:s', 'dest_dir=s', 'outfile=s', 'debug:s', 'key_name=s');

print "\nGetOptions got:\n";
print Dumper(\%config);
print "===\n";

if ($config{'debug'} >3) {
  my $go_on_girl= getc();
}

# validate input, prompting user for missing values as needed

if ($config{"src_dir"} eq "Data") {
# either they didn't specify it or they specified 'Data' ... we can't actually tell
    print "\nOK, using default src_dir of 'Data'\n";
}
#comment
my $same_dest_dir;
if (!defined($config{"dest_dir"})) {
    print "you didn't provide a destination directory.\n";
    my $question = "Use src_dir(=" . $config{"src_dir"} . ") as dest_dir?";
    $same_dest_dir = &ask("$question");
    if ($same_dest_dir =~ /Y/i) {
	$config{"dest_dir"} = $config{"src_dir"};
    } else {
	$config{"dest_dir"} = &ask("ok, then where?");
    }
}

if (!defined($config{"infile"})) {
    print "you didn't provide the name of an input file.";
    $config{"infile"} = &ask("Input file?");
}


if (!defined($config{"outfile"})) {
    print "you didn't provide an output filename.\n";
    my $default_outfile = "OUT_" . $config{"infile"};
    my $question = "Use outfile = " . $default_outfile . "?";
    $same_dest_dir = &ask("$question");
    if ($same_dest_dir =~ /Y/i) {
	$config{"outfile"} = $default_outfile
    } else {
	$config{"outfile"} = &ask("ok, then where?");
    }
}


# if a relative pathname was provided for src or dest directory,
# make it absolute

# from the Cwd module, get the current working directory
my $base_dir = getcwd;

if ($config{"src_dir"} !~ /$base_dir/i) {
    # append it
    print "Making src_dir absolute...\n";
    $config{"src_dir"} = "$base_dir" . "/" . $config{"src_dir"};
}

if ($config{"dest_dir"} !~ /$base_dir/i) {
    # append it
    print "Making dest_dir absolute...\n";
    $config{"dest_dir"} = "$base_dir" . "/" . $config{"dest_dir"};
}

# assemble _dirs and files into  paths 
$config{"in_path"} = $config{"src_dir"} . "/" . $config{"infile"};
$config{"out_path"} = $config{"dest_dir"} . "/" . $config{"outfile"};

# confess configuration
if ($config{'debug'} > 0) {
    print "Here's the configuration we ended up with:\n";
    print Dumper(\%config);
}


########################################################################
# PHASE TWO: BEGIN PROCESSING USER DATA FILE
########################################################################

my $line;
# get a file handle on the file
my $fh = IO::File->new("<$config{'in_path'}") or die "Couldn't open " . $config{'in_path'} . " for reading: $ERRNO\n";
my $ofh = IO::File->new(">$config{'out_path'}") or die "Couldn't open " .  $config{'out_path'} . " for writing: $ERRNO\n";
#open (OUT, ">$config{'out_path'}") or die "FAiled to open $ERRNO\n";



# turn it into a linebuffer object
my $datasrc = Data::LineBuffer->new($fh);


my $records_hr;
my $header;
my $each_record_hr;
my $key = $config{'key_name'};

my $proxy_key=1;

$header = $datasrc->get();
my @fields = split /\t/, $header;
print "Fields read from header are:\n",  Dumper(\@fields),"\n";

if ($config{'debug'} > 3) {
  my $go_on_girl= getc();
}

my $line_idx=0;
my $field_idx=0;
my @values;


my @bad_lines;
my @empty_key;
my @key_values;
LOOP: while (defined($line = $datasrc->get())) {
  $each_record_hr={};
  $line_idx++;
  print "\n-----\nProcessing line index, $line_idx...\n";

if ($config{'debug'} > 3) {
  my $go_on_girl= getc();
}

  if ($line =~ /^\s+$/) {
    print "blank line. . .skipping. . .\n";
    next LOOP;
  }


  @values = split /\t/, $line;
  print "Valuesfor line $line_idx are:\n";
  print Dumper(\@values);
  print "\n";
if ($config{'debug'} > 3) {
  my $go_on_girl= getc();
}
  $field_idx = 0;
  foreach my $field (@fields) {
    print "Line: $line_idx, Field: $field,  Val: $values[$field_idx] \n";
    $each_record_hr->{$field} = $values[$field_idx];
    $field_idx++;
  }
    print "Line: $line_idx record:\n";
    print Dumper($each_record_hr);
    print "---\n";

#  print $ofh Dumper($each_record_hr);
#  push @records, $each_record_hr;

  print "This key value ($key) for line $line_idx: \t", $each_record_hr->{$key},"\n";
  if (!defined($each_record_hr->{$key})) {
    print "$line_idx has undef for $key!\n";
    push @bad_lines, $line_idx;
    my $go_on_girl=getc();
  }


  if ($each_record_hr->{$key} =~ /\[\]/ ) {
    print "$line_idx was empty for $key!\n";
    push @empty_key, $line_idx;
    print "Using proxy key: $proxy_key\n";
    $each_record_hr->{$key} = $proxy_key;
    $proxy_key++;
    my $go_on_girl=getc() unless ($config{'debug'} < 4);
  }

  if (exists(  $records_hr->{$each_record_hr->{$key}})) {
    print "Hey! We already saw this ISBN!\n";
    my $new_key = $each_record_hr->{$key} . "_copy";
    $records_hr->{$new_key} = $each_record_hr;
    my $go_on_girl=getc();
  } else {
    $records_hr->{$each_record_hr->{$key}} = $each_record_hr;
  }

  push @key_values, $each_record_hr->{$key};
}

print $ofh "Records struct contains " . scalar(keys(%{$records_hr})) . " entries\n";
#print $ofh "\n=-=-=-=-\nThe Records struct:\n";
#print $ofh Dumper($records_hr);

# TODO: the DB table will be different depending on who we're following,
# defaulting to 'tweets'
my %lt;
#my $table = "lt_titles";
my $table = $config{'table_name'};

tie %lt,'Tie::DBI',{db       => 'mysql:librarything',
                   table    => $table,
                   key      => 'isbn',
                   user     => 'ltuser',
                   password => undef,
                   CLOBBER  => 1,
		   };

print "Fit to be tied. . .\n";
print tied %lt;

if ($config{'debug'} >3) {
  my $go_on_girl= getc();
}

print $ofh "\nThere were " .  scalar(@key_values) .  " key values seen in the input file\n";
print $ofh "\nWe processed " . $line_idx . " lines, not including the header line\n";
print $ofh "There were " . scalar(@bad_lines) .  "bad lines: \n" . Dumper(\@bad_lines) . "with undef for the specified key value\n";
print $ofh "There were " . scalar(@empty_key) . " empty keys: \n" . Dumper(\@empty_key) . " where the value for the specified key field was \'[]\'\n";



my $db_lt_map = {
		 "book_id" => "book id",
		 "date_entered" => "date entered",
		 "title" => "title",
		 "author_last_first" => "\"author (last, first)\"",
		 "author_first_last" => "\"author (first, last)\"",
		 "other_authors" => "other authors",
		 "summary" => "summary",
		 "publication" => "publication",
		 "date" => "date",
		 "ISBN" => "ISBNs",
		 "DDC" => "DDC",
		 "LCC" => "LLC",
		 "BCID" => "BCID",
		 "review" => "review",
		 "private_comments" => "private comments",
		 "language_1" => "language 1",
		 "language_2" => "language 2",
		 "original_language" => "original language",
		 "comments" => "comments",
		 "series" => "series",
		 "your_copies" => "your copies",
		 "stars" => "stars",
		 "encoding" => "encoding",
};


print "About to loop over records_hr\n";


if ($config{'debug'}>3) {
  my $go_on_girl= getc();
}

my $db_rows =0;
foreach my $isbn (sort(keys(%{$records_hr}))) {
  print $isbn,"\n";
  my $db_record = {};
  my $raw_record = $records_hr->{$isbn};
#  $db_record->{"isbn"} = $raw_record->{"ISBN"};
  # $db_record->{"book_id"} = $raw_record->{"_book id"};
  # $db_record->{"title"} = $raw_record->{"title"};
  # $db_record->{"author_last_first"} = $raw_record->{'"author (last, first)"'};
  # $db_record->{"author_first_last"} = $raw_record->{'"author (first, last)"'};
  # $db_record->{"publication"} = $raw_record->{"publication"};
  # $db_record->{"summary"} = $raw_record->{"summary"};

   foreach my $db_field (sort(keys(%{$db_lt_map}))) {
#     print "setting " . $db_field . " to " . $db_lt_map->{$db_field} . "\n";
     $db_record->{$db_field} = $raw_record->{$db_lt_map->{$db_field}};
     
     if (!defined( $raw_record->{$db_lt_map->{$db_field}})) {
        $raw_record->{$db_lt_map->{$db_field}} = "(blank)";
     }
     if ( $raw_record->{$db_lt_map->{$db_field}}  eq "(blank)" ) {
       print "Found blank for $db_field\n";
     }

   }

  $db_record->{"date_entered"} = &SQLDate($raw_record->{"date entered"});

   print Dumper($db_record);
  
  $lt{$isbn} = $db_record;
  $db_rows++;
}

print $ofh "And there were $db_rows rows in the database\n";


############################################################
##                    SUBROUTINES                         ##
############################################################

sub SQLDate() {
  # parse date into SQL format for insert
  my $raw_date = shift;
  my $parsed_date = ParseDate($raw_date);
  my $sql_date = UnixDate($parsed_date,$SQL_FMT);
  return $sql_date;
}

sub ask_from_list {
    my ($question, @answers) = @_;
    my $size = scalar(@answers);
    while (1) {
        print "$question?\n";
        for (my $i = 0 ; $i < $size ; $i++) {
            print "$i : $answers[$i]\n";
        }
        my $result = <STDIN>;
        chomp($result);
        return ($answers[$result]) if ($result >= 0 && $size >= $result);
    }
}

sub ask {
    my ($question, $accept_blank) = @_;

    while (1) {
        print $question . "\n";
        my $result = <STDIN>;
        chomp($result);
        return $result if (length($result) || $accept_blank);
    }
}

sub ask_long {
    my ($question) = @_;
    while (1) {
        print $question . "\n";
        print "(when you are finished typing your answer, type '.'\n";
        my $text;
        while (1) {
            my $line = <STDIN>;
            chomp($line);
            if ($line =~ /^\.$/) {
                if (length($text)) {
                    return ($text);
                } else {
                    last;
                }
            }
            $text .= $line;
        }
    }
}
