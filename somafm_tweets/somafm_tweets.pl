#!/usr/local/perl

use strict;
use Data::Dumper;
use English;
use Net::Twitter;
use DBI;
use DBD::mysql;
use Tie::DBI;
use Date::Manip;
use Log::Log4perl qw(get_logger :levels); 
use Getopt::Long;
use IO::File;


# d'apres oauth_desktop.pl to 
# store the access tokens
use File::Spec;
use Storable;


# for things that Tie::DBI can't handle
my $data_source = "DBI:mysql:tweets";
my $username = "root";
my $auth = "root";
my $dbh = DBI->connect($data_source, $username, $auth) or die "failed";
# command-line option processing courtesy of Getopt::Long;
my %options = (
	       "number" => 200,
	       "table" => "q_tweets",
	       "datafile" => "/Users/h/bin/somafm_tweets.dat",
	       "user_names" => "spacestationsma,indiepoprocks,dronezone,digitalis,groovesalad,thetrip,ericgarland",
	       "outfile" => "dump.txt"
	      );


GetOptions( \%options, 'help', 'number:i','table:s', 'user_names|users:s', 'since:s','my_username=s', 'my_password=s','outfile:s');

my $ofh = undef;
if (defined($options{'outfile'})) {
  print " \n";
  $ofh = IO::File->new(">>$options{'outfile'}") or die "Failed to open " .  $options{'outfile'} . " for writing: $ERRNO\n";
  print "Opened ". $options{'outfile'} . "for writing...\n";
} else {
  print "outfile not provided\n";
}


# connect to Twitter- now requiring oauth
# lifted from oauth_desktop.pl in examples for Net::Twitter

my %consumer_tokens = (
		       consumer_key => 'UtzzLqqC87ZR25YLKejUzg',
		       consumer_secret => 'afVHmqM4vwHsUEZIUnCGhFJbnsmuaNkma1hCaOeRw',
		      );

# $datafile = oauth_desktop.dat
#my (undef, undef, $datafile) = File::Spec->splitpath($0);
#$datafile =~ s/\..*/.dat/;
#hard-code the location of the data file with auth tokens

my $datafile = $options{'datafile'};


my $nt = Net::Twitter->new(ssl => 1, traits => [qw/API::RESTv1_1 OAuth/], %consumer_tokens);
my $access_tokens = eval { retrieve($datafile) } || [];

if ( @$access_tokens ) {
    $nt->access_token($access_tokens->[0]);
    $nt->access_token_secret($access_tokens->[1]);
}
else {
    my $auth_url = $nt->get_authorization_url;
    print " Authorize this application at: $auth_url\nThen, enter the PIN# provided to contunie: ";

    my $pin = <STDIN>; # wait for input
    chomp $pin;

    # request_access_token stores the tokens in $nt AND returns them
    my @access_tokens = $nt->request_access_token(verifier => $pin);

    # save the access tokens
    store \@access_tokens, $datafile;
}

## all authorized now. . .



# format string for parsedate/unixdate below to align with mysql
my $fmt  = "%Y-%m-%d %H:%M:%S";
my $http_date_fmt = "%g";
my ($httpdate,$httpdate_gmt,$since_parsed,$since_gmt,$since_twitter,$since_epoch);
if(defined($options{"since"})) {
  $since_parsed = ParseDate($options{"since"});
  $since_gmt = Date_ConvTZ($since_parsed,"","GMT");
  $httpdate = UnixDate($since_parsed, $http_date_fmt);
  $httpdate_gmt = UnixDate($since_gmt, $http_date_fmt);
  
  $since_twitter = UnixDate($since_gmt,$fmt);
  $since_epoch = UnixDate($since_parsed,"%s");
  print "\nSince (parsed)\n";
  print $since_parsed;
  print "\n";
  print "\nSince (gmt)\n";
  print $since_gmt;
  print "\n";
  print "\nSince (httpdate)\n";
  print $httpdate;
  print "\n";
  print "\nSince (httpdate gmt)\n";
  print $httpdate_gmt;
  print "\n";
  print "\nSince (twitter format)\n";
  print $since_twitter;
  print "\n";
}


# who to follow
# fetch list of friends for $options('my_username')
my $results_ar;
my @friends = ();


# this gives the timeline; just extract the screen name
foreach my $result_hr (@{$results_ar}){
  push @friends, $result_hr->{"screen_name"};
}
# me too!
push @friends, 'xoanon93';

# people to track who you do not actually follow
my @stalkees = qw(romkey  lionsburg);

my @users;
# if a specific list of users were specified, use only that list.
if (defined($options{'user_names'})) {
  @users = split(/,/, $options{'user_names'});
} else {
# $options{'users'} = ['arkma','gdaniels','dronezone','romkey','pie_girl','billmarrs','lionsburg','sneeper','xoanon93'],
  my  @list;
  unshift(@list,@friends);
  unshift(@list,@stalkees);
  $options{'user_names'} = \@list;
}


# Echo the results so we know who we're snarfing
print Dumper(\%options);


# TODO: the DB table will be different depending on who we're following,
# defaulting to 'tweets'
my %tw;
my $table = defined($options{'table'})?$options{'table'}:"tweets";

tie %tw,'Tie::DBI',{db       => 'mysql:tweets',
                   table    => $table,
                   key      => 'status_id',
                   user     => 'h',
                   password => undef,
                   CLOBBER  => 1,

		   };





# TODO: combine these two loops, we really don't need both

# fetch timelines, store in $results_hr hashed on username from @users
my $results_hr;

foreach my $user (@users) {
  print "Fetching timeline for $user...\n";
#  if (defined($options{"since"})) {
#    print "Since " . $options{'since'} . " . .\n";
#    $results_hr->{$user} = $nt->user_timeline({"id" => $user, "count" => $options{"number"}, "since" => $since_epoch });
#  } else {
#    print "Since not defined, getting all. . .\n";
    $results_hr->{$user} = $nt->user_timeline({"id" => $user, "count" => $options{"number"} });
#  }
}


print "Done. Formatting results for insert into DB\n";
#print Dumper($results_hr);

my $responses_hr = {};
my $format_tweet_hr = {};
my $key;
foreach my $user (@users) {
  print "Formatting results for $user...\n";
#  my $format_tweet_hr = {};
  foreach my $res (@{$results_hr->{$user}}) {
    
    # shuffle data from Twitter return into format
    # suitable for assigning to tied hash
#    print "The result id was ", $res->{"id"};
    $format_tweet_hr->{"status_id"} = $res->{"id"};

    # fix up the date in a format palatable to mysql datetime field
    my $created_at = ParseDate($res->{"created_at"});
    my $created_at_sql = UnixDate($created_at,$fmt);
    $format_tweet_hr->{"created_at"} = $created_at_sql;

    # flatten out the user information which is returned inline
    # TODO: Does this info ever change?
    $format_tweet_hr->{"user_id"} = $res->{"user"}{"id"};
    $format_tweet_hr->{"user_name"} = $res->{"user"}{"screen_name"};
    $format_tweet_hr->{"user_location"} = $res->{"user"}{"location"};

    $format_tweet_hr->{"status_source"} = $res->{"source"};

#    $format_tweet_hr->{"status_text"} = $res->{"text"};

    my $raw_text =  $res->{"text"};

    # Try to transform the raw text into just the string 'artist - title'
    # this used to work by splitting on the 'musical note' character but
    # stopped working somewhere around may 2016 causing the resulting text to be undef

    # used to work
    #my @bits = split /\x{266c}/, $raw_text;
    # try splitting on space first
    my @space_bits = split /\s+/, $raw_text;
    # print Dumper(\@space_bits);

    # Sanitize using map , codepoint 9836 is the bad character; nuke it
    my @charpoints = map {ord($_) == 9836?"":$_} @space_bits;
    # then join with spaces
    my $sanitized_string = join(" ",@charpoints);

    # now split on 'https'
    my @http_bits = split/https/, $sanitized_string,2;
    #print Dumper(\@http_bits);

    # and take the 0th bit
    $format_tweet_hr->{"status_text"} = $http_bits[0];


    $format_tweet_hr->{"in_reply_to_status_id"} = $res->{"in_reply_to_status_id"};
    $format_tweet_hr->{"in_reply_to_user_id"} =  $res->{"in_reply_to_user_id"};
    $format_tweet_hr->{"in_reply_to_screen_name"} = $res->{"in_reply_to_screen_name"};
# not sure what to do with these yet, the format returned seems to vary
    $format_tweet_hr->{"favorited"} = undef;
    $format_tweet_hr->{"truncated"} = undef;
#TODO:  add logger to this script and conver these print statements
# into logger calls
#    print "\n";
#    print Dumper($format_tweet_hr);
#    print "Committing to DB...\n";
# assign to tied hash, autocommit is on 
#    $tw{$res->{"id"}} = $format_tweet_hr;
##    tied(%tw)->commit;
    $responses_hr->{$user}{$format_tweet_hr->{"status_id"}} = $format_tweet_hr;
    $format_tweet_hr = undef;
  }
  
}
print $ofh "Responses hash\n";
print $ofh Dumper($responses_hr);
print $ofh "="x50 , "\n";
my $response_key = undef;
my $user;
foreach $user (sort ( keys(%{$responses_hr}))) {
  foreach  $response_key (sort(keys(%{$responses_hr->{$user}}))) {
    my $row_hr = $responses_hr->{$user}{$response_key};
    print $ofh "Response_key = $response_key\n";
    print $ofh "Row:\n";
    print $ofh Dumper($row_hr);
    my $sth = $dbh->prepare( qq{
INSERT INTO $options{'table'} (status_id,created_at,user_id,user_name,user_location,status_source,status_text,in_reply_to_status_id,in_reply_to_user_id,in_reply_to_screen_name,favorited,truncated) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)});
#    print "Butbutbut: " . $row_hr->{'status_id'} . "\n";
    $sth->execute($row_hr->{'status_id'},
		  $row_hr->{'created_at'},
		  $row_hr->{'user_id'},
		  $row_hr->{'user_name'},
		  $row_hr->{'user_location'},
		  $row_hr->{'status_source'},
		  $row_hr->{'status_text'},
		  $row_hr->{'in_reply_to_status_id'},
		  $row_hr->{'in_reply_to_user_id'},
		  $row_hr->{'in_reply_to_screen_name'},
		  $row_hr->{'favorited'},
		  $row_hr->{'truncated)'}
		 );
    
    
    #  $tw{$row_hr->{"status_id"}} = $row_hr;
    #  tied(%tw)->commit;
    #  $response_key = undef;
    #print Dumper(\%tw);
    $response_key = undef;
  }
}


sub print_usage() {

#GetOptions( \%options'}, 'number:i')

  print "Usage: t.pl <options>\n";
  print "\tnumber  \t\t\t\t how many statuses to retrieve per user\n";
  print "\tuser_names, users \t\t\t\t comma-delim. list of users to retrieve status\n";
  print "\tsince \t\t\t\t date/time from whence to retrieve data for specified user(s). \n";

}


__END__
# sample return from Net::Twitter
$VAR1 = {
          'source' => 'web',
          'favorited' => bless( do{\(my $o = 0)}, 'JSON::XS::Boolean' ),
          'truncated' => $VAR1->{'favorited'},
          'created_at' => 'Thu Dec 18 09:27:24 +0000 2008',
          'text' => 'wait what how did @romkey achieve greater than my updates X 2???',
          'user' => {
                      'location' => 'iPhone: 42.390289,-71.120956',
                      'followers_count' => 42,
                      'protected' => $VAR1->{'favorited'},
                      'name' => 'arkma',
                      'url' => 'http://arkma.blogspot.com',
                      'profile_image_url' => 'http://s3.amazonaws.com/twitter_production/profile_images/54598392/391_42_2_normal.jpg',
                      'id' => 14273107,
                      'description' => 'Borscht Belt comic 2.0',
                      'screen_name' => 'arkma'
                    },
          'in_reply_to_user_id' => undef,
          'id' => 1064615899,
          'in_reply_to_status_id' => undef,
          'in_reply_to_screen_name' => undef
        };



# SQL for table create (mysql)
CREATE TABLE IF NOT EXISTS `tweets` (
  `status_id` int(64) NOT NULL,
  `created_at` datetime NOT NULL,
  `user_id` int(64) NOT NULL,
  `user_name` varchar(128) NOT NULL,
  `user_location` varchar(128) default NULL,
  `status_source` varchar(128) NOT NULL,
  `status_text` varchar(400) NOT NULL,
  `in_reply_to_status_id` int(64) default NULL,
  `in_reply_to_user_id` int(64) default NULL,
  `in_reply_to_screen_name` varchar(128) default NULL,
  `favorited` varchar(128) default NULL,
  `truncated` varchar(128) default NULL,
  UNIQUE KEY `id` (`status_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

