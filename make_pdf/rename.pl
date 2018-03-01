use strict;
use Getopt::Long;
use Data::Dumper;
use File::Copy;
use File::Path qw(mkpath);

my %opts = ("src_path" => "/Users/h/Desktop/Podcasts/RuneSoup",
	    "dest_path" =>"/Users/h/Desktop/Podcasts/RuneSoup_renamed",
	    "inpat" => "Rune_Soup_Episode_",
	    "outpat" => "Ep_"
    );

GetOptions(\%opts,"src_path:s","dest_path:s","inpat:s","outpat:s");

print Dumper(\%opts);

if (!(-d $opts{'dest_path'})) {

    print "Destination path $opts{'dest_path'} doesn't exist, creating\n";
    mkpath($opts{'dest_path'});
}

my $file;
my $newfile;
my $src_target; 
my $dest_target;

opendir DIR,$opts{'src_path'};
while($file = readdir(DIR)) {
    print "Saw $file\n";
    $newfile = $file;
    $newfile =~ s/$opts{'inpat'}/$opts{'outpat'}/xg;
    $newfile =~ s/_-_/_/;
    print "Got $newfile\n";

    print "\n";
    $src_target = $opts{'src_path'} . "/" . $file;
    $dest_target = $opts{'dest_path'} . "/" . $newfile;
    print "would copy $src_target to $dest_target\n";
    $newfile = undef;
    copy($src_target,$dest_target);

}
