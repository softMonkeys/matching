use warnings;
use strict;
use Getopt::Long;

srand(7); # manually seed the rng for some consistency

my $dir = 'www-extract-tra/';
my $f_words_file = 'FunctionWords.txt';
my %f_words = ();

GetOptions(
    "d=s" => \$dir,
    "fw=s" => \$f_words_file,
);

die "No directory!" unless -e "$dir";
$dir =~ s/\/$//g;
my @files = glob "$dir/*";
die "Empty directory!" unless @files;

open FILE1, "<:encoding(UTF-8)", $f_words_file || die $!;
while(<FILE1>)
{
	chomp;
	s/[^a-z']//g;
	my $key = $_;
	#print "$key ";
	$f_words{$key} = '1'; #Create hash set will all words; value not overly important
}
close FILE1 || die $!;

$f_words{'rawtext'} = 1;
$f_words{'ampamp'} = 1;
$f_words{'amp'} = 1;

my $num_apps = 0;
my %tf_sum = ();
my %apps_with_word = ();

foreach my $f (@files) {
    my $app_label = '';
    my @saved_lines = ();
    my %jobdesc = ();

    open FILE, '<', $f || die $!;
    while (<FILE>) {
	chomp;
	my $line = $_;

	my $field = '';
        if ($line =~ /^\s+"(.+)":\s+/) {
            $field = $1;
        }
	if ($field =~ /stage/) {
	    if ($line =~ /Rejected/i) {
		$app_label = '-1';
	    }
	    elsif ($line =~ /New/i) {
		$app_label = '0';
	    }
	    else {
		$app_label = '+1';
	    }
	}

	if ($app_label eq '+1' && $field =~ /rawText/) {
	    $num_apps++;

	    $line =~ s/\\n/ /g;
	    $line = lc($line);
	    $line =~ s/[^\w\d\s]//g;
	    $line =~ s/^\s+//g;
	    $line =~ s/\s+$//g;
	    $line =~ s/\s+/ /g;

	    push @saved_lines, $line;

	    $app_label = '';
	}

	if ($field =~ /job/) {
            $line =~ s/\\n/ /g;
            $line = lc($line);
            $line =~ s/[^\w\d\s]//g;
            $line =~ s/^\s+//g;
            $line =~ s/\s+$//g;
            $line =~ s/^job//g;
            $line =~ s/\s+/ /g;

            foreach my $w (split /\s+/, $line) {
                $jobdesc{$w} = 1;
            }
	}
    }
    close FILE || die $!;

    foreach my $l (@saved_lines) {
	my $words = 0;
	my %count = ();
	my %seen = ();
	foreach my $w (split /\s+/, $l) {
	    if ($jobdesc{$w} && !$f_words{$w}) {
		$words++;
		$count{$w}++;
		next if $seen{$w};
		$seen{$w} = 1;
		$apps_with_word{$w}++;
	    }
	}
	foreach my $w (sort keys %count) {
	    $tf_sum{$w} += ($count{$w} / $words);
	}
	
    }
}

my %a_tf_idf = ();
foreach my $w (sort keys %apps_with_word) {
    $a_tf_idf{$w} = $tf_sum{$w} * log($num_apps / $apps_with_word{$w}++) / $num_apps;
}

foreach my $w (sort {$a_tf_idf{$b} <=> $a_tf_idf{$a}} keys %a_tf_idf) {
    print "$a_tf_idf{$w}\t$w\n";
}

sub plogp {
    my $p = shift;
    return ($p * log($p)/log(2));
}
