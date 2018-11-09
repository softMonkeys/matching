use warnings;
use strict;

# usage: cat www-extract-tra/* | grep '"job":' | perl get_all_jobs.pl

while (<STDIN>) {
    chomp;
    my $l = $_;
    $l =~ s/\\n/ /g;
    $l = lc $l;
    $l =~ s/[^\w\d\s]/ /g;
    $l =~ s/^\s+//g;
    $l =~ s/\s+$//g;
    $l =~ s/\s+/ /g;
    $l =~ s/^\s*job\s*//g;
    print "$l\n";
}
