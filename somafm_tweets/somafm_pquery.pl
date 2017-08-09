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
pQuery("http://somafm.com/groovesalad/songhistory.html")
    ->find("tr")
    ->each(sub {
	pQuery($_)->find("td")
	    ->each(sub {
		push @{$row_ar}, pQuery($_)->text;
		   });
	push @{$rows_ar}, $row_ar;
	$row_ar = undef;
	   });

print Dumper($rows_ar);
