use warnings;
use strict;
use Getopt::Long;

srand(7); # manually seed the rng for some consistency

#get_keywords_tf-idf.pl
#Extract keywords from resumes using tf-idf
#Written by: Bradley Hauer, 
#Summer 2016

#TF-IDF works on the assumption that the most informative words are
#ones that appear often, but only in a small number of documents

#usage perl get_keywords_tf-idf.pl (-d) (-fw)
#-d indicates directory where applications are stored
#-fw indicates file listing function words

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
	s/[^a-z']//g; #Strip all non alphabetic characters from function words
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

foreach my $f (@files) { #Open files one by one, and extract all potential
			 #words, along with their statistics
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
		$app_label = '-1';
	    }
	    elsif ($line =~ /New/i) {
		$app_label = '0';
	    }
	    else {
		$app_label = '+1'; #All non-rejected or new are accepted
	    }
	}

	if ($app_label eq '+1' && $field =~ /rawText/) {
	    $num_apps++;

	    #Tokenization and punctuation stripping

	    $line =~ s/\\n/ /g; #convert newlines to spaces
	    $line = lc($line); #lowercase everything
	    $line =~ s/[^\w\d\s]//g; #Strip non alpha-numeric characters (ie punctuation)
	    $line =~ s/^\s+//g; #trim lines and reduce multiple spaces
	    $line =~ s/\s+$//g;
	    $line =~ s/\s+/ /g;

	    my $words = 0;
	    my %count = ();
	    my %seen = ();
	    foreach my $w (split /\s+/, $line) {
		unless ($f_words{$w}) {
		    $words++;
		    $count{$w}++; #keep track of the number of times we've seen
				  # w
		    next if $seen{$w};
		    $seen{$w} = 1;
		    $apps_with_word{$w}++; #keep track of the number of 
					   #documents that contain w
		}
	    }
	    foreach my $w (sort keys %count) {
		$tf_sum{$w} += ($count{$w} / $words); #Add the normalized sum
	    }
	    $app_label = '';
	}
    }
    close FILE || die $!;
}

my %a_tf_idf = ();
foreach my $w (sort keys %apps_with_word) { #Calculate tf-idf
    $a_tf_idf{$w} = $tf_sum{$w} * log($num_apps / $apps_with_word{$w}++) / $num_apps;
}

foreach my $w (sort {$a_tf_idf{$b} <=> $a_tf_idf{$a}} keys %a_tf_idf) {
    print "$a_tf_idf{$w}\t$w\n"; #Sort by tf-idf
}

sub plogp {
    my $p = shift;
    return ($p * log($p)/log(2));
}
