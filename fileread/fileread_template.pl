#!/usr/local/perl
use strict;
use warnings;
use Getopt::Long;
use IO::File;
use Data::LineBuffer;
use Data::Dumper;
use Cwd;
use English;

# config hash (with a few defaults)
my %config = (
    src_dir => 'Data',	      
);

# PHASE 0: COMMAND LINE ARGUMENT MARSHALLING

# If you require more command line arguments, add them here. 
# read the documentation for the Getopt::Long module 
GetOptions(\%config, 'src_dir=s','infile=s','dest_dir=s', 'outfile=s', 'debug:s');

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
if ($config{'debug'}) {
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

# turn it into a linebuffer object
my $datasrc = Data::LineBuffer->new($fh);


while (defined($line = $datasrc->get())) {
    print $line,"\n";
}






############################################################
##                    SUBROUTINES                         ##
############################################################

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
