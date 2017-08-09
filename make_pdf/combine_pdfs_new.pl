use strict;
#use PDF::API2;
use PDF::API2::Lite;
use CAM::PDF;
use Getopt::Long;
use File::Finder;
use File::Find;
use Data::Dumper;

# scans a directory containing image files (JPGS)
# creates a single PDF document containing the images

my %options;

GetOptions(\%options, "src_dir:s","dest_dir:s","debug:s", "outfile:s");

# validate input and command-line opts
if (defined($options{"debug"}) ) {
  print Dumper(\%options);
}

# directory to begin scanning; is assumed to contain
# a set of subdirs one level deep each of which contain the images
if (!defined($options{'src_dir'})) {
  $options{'src_dir'} = &ask("source root directory? ");
}

# # dest_dir is where the created PDFs accumulate, if 
# # not provided, write them to the root (src_dir)
# if (!defined($options{'dest_dir'})) {
#   print "destination directory not provided, using src_dir to collect generated PDFs.\n";
#   $options{'dest_dir'} = $options{'src_dir'};
# }



# outline
# from src_dir scan for pdfs to get a list of subfolders, save in array
# for each subfolder under src_dir, scan it for images of the appropriate type
# turn those images into a single PDF 
# save resulting PDF named after the subfolder

#TODO scan src_dir for directories
my $pdf_finder = File::Finder->type('f');
# TODO add step to filter only for pdfs
my @src_pdfs = $pdf_finder->in($options{'src_dir'});

# set the accumulator to the first 

my $first = shift(@src_pdfs);

if ($first =~ /DS/) {
    print "The first is. . ." . $first . "skipping\n";
    $first = shift(@src_pdfs);
}

my $total = CAM::PDF->new($first);

# TODO wrap loop here to loop over subdirs
my $current;
LOOP: foreach my $pdf (@src_pdfs) {
  print "$pdf\n";
  if ($pdf !~ /\.pdf/) {
    print "Skipping $pdf...\n";
    next LOOP;
  }

  print "Reading $pdf  ...\n";
  $current = CAM::PDF->new($pdf);

  print "Appending $pdf  ...\n";
  $total->appendPDF($current);
  $current=undef;

}

print "Writing output...";
my @src_dir_bits = split /\//, $options{'src_dir'};
if (!defined($options{'outfile'})) {
# get last portion of src_dir

  my $name = pop(@src_dir_bits);
  print "Output filename not provided.\n";
  my $response = &ask(" use $name?");
  if ($response =~ /[Yy]/) {
    $options{'outfile'} = $name;
  } else {
    my $othername = &ask("Then where?");
    $options{'outfile'} = $othername;
  }

}
if ($options{'outfile'} !~ /\.pdf$/) {
  $options{'outfile'} .= ".pdf";
}

if (!defined($options{'dest_dir'})) {
  print "Output directory not given.\n";
  my $dest_dir_candidate = join("/",@src_dir_bits);
  my $resp = &ask("use $dest_dir_candidate?");

  if ($resp =~ /[Yy]/) {
    $options{'dest_dir'} = $dest_dir_candidate;
  } else {
    my $other_dir = &ask("Then where?");
    $options{'dest_dir'} = $other_dir;
  }

}

my $outpath = $options{'dest_dir'} . "/" . "/" . $options{'outfile'};
$total->cleanoutput($outpath);

print "...done\n";


##  Utility Subroutines
sub ask {
    my ($question, $accept_blank) = @_;

    while (1) {
        print $question . "\n";
        my $result = <STDIN>;
        chomp($result);
        return $result if (length($result) || $accept_blank);
    }
}

sub cleanse_string {
  my $raw_string = shift;
  my $cleansed= $raw_string;
  $cleansed =~ s/-//g;
  $cleansed =~ s/\#//g;
  $cleansed =~ s/\s+/_/g;
  $cleansed =~ s/Promothea/Promethea/;

  return $cleansed;
}


__END__
my $image = $pdf->image_jpeg( "$dir/$jpg" );
    $pdf->page( $image->width, $image->height );
    $pdf->image( $image, 0, 0 );
}

$pdf->saveas( $output_file );
