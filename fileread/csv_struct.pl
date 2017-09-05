#!/usr/local/perl

# TODO: clean up unused modules (some already gone, P4)
# make delimiter an argument (how to pass in a tab?)

use strict;
use Data::Dumper;
use IO::File;
use Getopt::Long;

use English;
use Date::Manip;
use Array::Diff;
use Data::LineBuffer;

my %options = (

	      "delimiter" => ",",
	      "group_by_key" => "row_number",
	      "problem_file" => "bad_issues.txt",
	       "report_file_prefix" => "report_file",
	      );

my $connection_pool;

GetOptions(\%options,"infile=s",
	   "group_by_key:s", # if not provided, group by row number in input file
	   "src_path|infile:s",
	   "in_keys:s", # if not provided, assume first line contains column headers, use as keys into row hashes
	   "delimiter:s",
	  );

my $go_on; #throw-away var to hold result of getc when pausing

my $ifh = IO::File->new("<$options{'src_path'}") or die "Failed to open $options{'src_path'} for reading : $ERRNO\n";

# turn it into a linebuffer object
my $datasrc = Data::LineBuffer->new($ifh);
   
my $values_hr = {};

my @in_keys;

#my @in_keys = qw(jiraissueid pkey timeoriginalestimate jobname);
if (  (!defined($options{'in_keys'}))   or ($options{'in_keys'} eq "first_row") ) {
  # grab first line as keys:
  my $first_line = $datasrc->get();
  if ($options{'debug'}) {
    print "The first line was....\n";
    print $first_line;
    $go_on=getc();
  }

  @in_keys = split /\t/x, $first_line;

} else {
  # use provided argument as list of input keys, comma-separated
  @in_keys = split /\t/, $options{'in_keys'};
}


if ($options{'debug'}) {
  print  Dumper(\@in_keys);
  $go_on=getc();
}


# remove quotes, replace spaces with a single underscore
my @in_keys = map {&cleanse($_)} @in_keys;

if ($options{'debug'} ){
  print  Dumper(\@in_keys);
  $go_on=getc();
}

my $group_by_key = $options{"group_by_key"};

my $rows_hash;

my @bad_issues;
my @key_mismatch;
my $row_idx=0;
LINES: while (my $line = $datasrc->get() ) {
  my $row_hr;
  if (($line =~ /^\#/)  ){
    print "skipping comment. . .\n";
    next LINES;
  }
  my @vals = split /,/, $line;
#  print Dumper(\@vals);
  my  $key_idx = 0;
  foreach my $inkey (@in_keys) {
    print "assigned $vals[$key_idx] to $inkey from index $key_idx","\n" if ( $options{'debug'});
    $row_hr->{$inkey} = $vals[$key_idx];

   $key_idx++;
  }
  $row_hr->{"row_number"} = $row_idx;

  $rows_hash->{$row_hr->{$options{'group_by_key'}}} = $row_hr;
  $row_idx++;
} # end of lineloop;



print Dumper($rows_hash);



#SUBROUTINES
sub cleanse() {
  my $bad_string = shift;
  my $clean_string;
  $clean_string = $bad_string;

  $clean_string =~ s/\"//g;
  $clean_string =~ s/\s+/_/g;

return $clean_string;
}



# ask, ask_from_list, ask_long
# utility functions to prompt for a value
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

