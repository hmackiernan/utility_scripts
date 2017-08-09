use pQuery;
use Data::Dumper; 

# pQuery("http://somafm.com/groovesalad/songhistory.html")
#     ->find("td")
#     ->each(sub {
#         my $i = shift;
#         print $i + 1, ") ", pQuery($_)->text, "\n";
# 	   });

my $rows_ar;
my $row_ar;
pQuery("http://necronomicon-providence.com/programming/")
  ->find("strong")->each(sub {
		       print Dumper($_);
		     });


