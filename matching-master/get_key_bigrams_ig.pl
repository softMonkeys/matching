use warnings;
use strict;
use Getopt::Long;

#get_keywords_ig.pl
#Extract keywords from resumes using Information gain
#Written by: Bradley Hauer
#Summer, 2016

srand(7); # manually seed the rng for some consistency

#usage: perl get_keywords_ig.pl (-d) (-fw)
#-d indicates directory of files from which to extract keywords
#-fw indicates file of function words to ignore when extracting keywords

my $dir = 'www-extract-tra/';
my $f_words_file = 'FunctionWords.txt';
my %f_words = ();

GetOptions(
    "d=s" => \$dir,
    "fw=s" => \$f_words_file,
);

die "No directory!" unless -e "$dir"; #Make sure the directory exists
$dir =~ s/\/$//g; #delete sequence final slashes
my @files = glob "$dir/*";
die "Empty directory!" unless @files;

open FILE1, "<:encoding(UTF-8)", $f_words_file || die $!;
while(<FILE1>)
{
	chomp;
	s/[^a-z']//g; #remove non-alphabetic chars 
	my $key = $_;
	#print "$key ";
	$f_words{$key} = '1'; #Create hash set will all words; value not overly important
}
close FILE1 || die $!;

$f_words{'rawtext'} = 1;
$f_words{'ampamp'} = 1;
$f_words{'amp'} = 1;

my $num_apps = 0;
my $pos_apps = 0;
my $neg_apps = 0;

my %apps_with_word = ();
my %apps_without_word = ();
my %pos_with_word = ();
my %pos_without_word = ();
my %neg_with_word = ();
my %neg_without_word = ();

foreach my $f (@files) {
    my $app_label = '';

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
		$app_label = '-1'; #Negative example
	    }
	    elsif ($line =~ /New/i) {
		$app_label = '0'; #To be discarded
	    }
	    else {
		$app_label = '+1'; #All other examples are positive
	    }
	}

	if (($app_label eq '+1' || $app_label eq '-1') && $field =~ /rawText/) {
	#Throw out '0' resumes as uninformative & extract keywords
        #From rawtext of other resumes.
	    $num_apps++;
	    if ($app_label eq '+1') {
		$pos_apps++;
	    }
	    elsif ($app_label eq '-1') {
		$neg_apps++;
	    }
	    else {
		die;
	    }

	    #Tokenization and punctuation stripping
	    $line =~ s/\\n/ /g;
	    $line = lc($line);
	    $line =~ s/[^\w\d\s]//g;
	    $line =~ s/^\s+//g;
	    $line =~ s/\s+$//g;
	    $line =~ s/\s+/ /g;

	    my %seen = ();
	    my @words = split /\s+/, $line;
	    for (my $i = 1; $i < @words; $i++) {
		my $v = $words[$i-1];
		my $w = $words[$i];
		my $bigram = "$v $w";
		unless ($f_words{$v} || $f_words{$w}) {
		    #print "$w\n";
		    next if $seen{$bigram}; #keep going if the word has alredy been noted
		    $seen{$bigram} = 1;
		    $apps_with_word{$bigram}++;
		    if ($app_label eq '+1') {
			$pos_with_word{$bigram}++;
		    }
		    elsif ($app_label eq '-1') {
			$neg_with_word{$bigram}++;
		    }
		    else {
			die;
		    }
		}
	    }
	    $app_label = '';
	}

    }
    close FILE || die $!;
}

my %information_gain = (); #calculate IG
foreach my $w (sort keys %apps_with_word) {
    $pos_with_word{$w} = 1 unless $pos_with_word{$w};
    $neg_with_word{$w} = 1 unless $neg_with_word{$w};
    my $entropy_before = -plogp($pos_apps/$num_apps) - plogp($neg_apps/$num_apps);#Entropy without considering the word
    my $entropy_with_word = -plogp($pos_with_word{$w} / $apps_with_word{$w}) - plogp($neg_with_word{$w} / $apps_with_word{$w});#Entropy when word is considered
    my $entropy_without_word = -plogp(($pos_apps - $pos_with_word{$w}) / ($num_apps - $apps_with_word{$w})) - plogp(($neg_apps - $neg_with_word{$w}) / ($num_apps - $apps_with_word{$w})); #Entropy of documents without the word
    my $entropy_after = ($apps_with_word{$w} / $num_apps) * $entropy_with_word + (($num_apps-$apps_with_word{$w}) / $num_apps) * $entropy_without_word; #Sum in entropy between documents with the word and without
    $information_gain{$w} = $entropy_before - $entropy_after;
}

foreach my $w (sort {$information_gain{$b} <=> $information_gain{$a}} keys %information_gain) {
    print "$information_gain{$w}\t$w\n";#Sort the keywords by information gain
}

sub plogp {
    my $p = shift;
    return ($p * log($p)/log(2));
}
