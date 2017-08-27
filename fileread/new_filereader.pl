#!/usr/local/perl
use strict;
use warnings;
use Getopt::Long;
use IO::File;
use Data::LineBuffer;
use Data::Dumper;
use Cwd;
use English;
use File::Find;

# config hash (with a few defaults)
my %config = (
	      
);

# PHASE 0: COMMAND LINE ARGUMENT MARSHALLING

# If you require more command line arguments, add them here. 
# read the documentation for the Getopt::Long module 
GetOptions(\%config, 'src_path=s','dest_path=s','filter_pattern:s', 'debug:s');

if ($config{'debug'}) {
	print "Config was:\n";
	print Dumper(\%config);
	
	
}


if (defined($config{src_path})) {
	print "you provided $config{'src_path'} ";
	if (-e $config{src_path}) {
		if (-d $config{src_path}) {
			print " which is a directory\n";
		} elsif (-f $config{src_path}) {
			print "which is a plain file";
		} else {
			print "which I have _no_ idea what it is\n."
		}
	} else {
		print "which does not exist.\n";
	}
}