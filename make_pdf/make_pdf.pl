use strict;
#use PDF::API2;
use PDF::API2::Lite;
use Getopt::Long;
use File::Finder;
use File::Find;
use Data::Dumper;

# scans a directory containing image files (JPGS)
# creates a single PDF document containing the images

my %options;

GetOptions(\%options, "src_dir:s","dest_dir:s","debug:s", "outfile_prefix:s");

# validate input and command-line opts
if (defined($options{"debug"}) ) {
  print Dumper(\%options);
}

# directory to begin scanning; is assumed to contain
# a set of subdirs one level deep each of which contain the images
if (!defined($options{'src_dir'})) {
  $options{'src_dir'} = &ask("source root directory?");
}

# dest_dir is where the created PDFs accumulate, if 
# not provided, write them to the root (src_dir)
if (!defined($options{'dest_dir'})) {
  print "destination directory not provided, using src_dir to collect generated PDFs.\n";
  $options{'dest_dir'} = $options{'src_dir'};
}



# outline
# from src_dir scan for directories to get a list of subfolders, save in array
# for each subfolder under src_dir, scan it for images of the appropriate type
# turn those images into a single PDF 
# save resulting PDF named after the subfolder



#TODO scan src_dir for directories
my $dir_finder = File::Finder->type('d');
my @src_subdirs = $dir_finder->in($options{'src_dir'});


# check for assumption of directory structure
if (scalar(@src_subdirs) == 1) {
    print "No other directories but '.' found in " . $options{'src_dir'} . "  we assume Dir/dir1 Dir/dir2 ... etc.\n";
exit 1;
}

# TODO wrap loop here to loop over subdirs
LOOP: foreach my $subdir (@src_subdirs) {
  next LOOP if ($subdir eq $options{'src_dir'});
  # TODO: change this to derive the output filename from the subdir, not the destdir
  my @subdirbits = split /\//, $subdir;
  my $output_filename =  pop(@subdirbits);
  
  $output_filename = $options{'outfile_prefix'} . $output_filename if (defined($options{'outfile_prefix'}));

  $output_filename .= ".pdf";

  my $clean_output_filename = &cleanse_string($output_filename);
  
  print "\nScanning $subdir, ....";
  my $output_path = $options{'dest_dir'} . "/" . $clean_output_filename;
  print "output path is $output_path";

  my $pdf = PDF::API2::Lite->new;
  &combine_images($subdir,$pdf);
  $pdf->saveas($output_path);
}


sub combine_images() {
  # scans provided subdir for files ending in 'jpg'
  # creates a PDF and returns the PDF::API2::Lite object
  my $subdir = shift;
  my $pdf = shift;
  # File::Finder steps "plain files named *.jpg"
  my $all_jpegs = File::Finder->type('f')->left->name("*.jpg")->or->name("*.JPG")->right;
#  my $all_jpegs = File::Finder->type('f');
  my @results = $all_jpegs->in($subdir);
  my $number = scalar(@results);
  print "\n\tFound $number files in $subdir\n";

  foreach my $file(sort {$a <=> $b} (@results)) {
    my $image = $pdf->image_jpeg( "$file" );
    $pdf->page( $image->width, $image->height );
    $pdf->image( $image, 0, 0 )
  }
  #$pdf->saveas( $output_file );
  return $pdf;
}

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
