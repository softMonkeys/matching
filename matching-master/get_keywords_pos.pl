use warnings;
use strict;
use Getopt::Long;

srand(7); # manually seed the rng for some consistency

#get_keywords_pos.pl
#Find keywords by their appearance in positive documents; at this point, they are not sorted in any meaningful way
#Written by: Bradley Hauer
#Summer, 2016


#Usage: perl get_keywords_pos.pl (-d) (-fw) (-c) (-i) (-t) (-o) > outputFile.txt
#-d is directory pointing to applications
#-fw is a file with a list of function words
#-c indicates whether to use count features
#-t indicates whether to use threshold features
#-o indicates whether to use overlap features #Note: these three parameters don't actually do anything

my $dir = '';
my $count_features = 1;
my $threshold_features = 1;
my $overlap_features = 1;
my $f_words_file = 'FunctionWords.txt';
my %f_words = ();
my %job_description = ();

my $inc_new = 0; # Include unlabeled instances ("new")
my $sample_rejects = 1; # Skip some negative ("reject") instances
my $reject_proportion = 0.9; # Proportion of NEGATIVE ("reject") instances to skip

GetOptions(
    "d=s" => \$dir,
    "fw=s" => \$f_words_file,
    "c=i" => \$count_features,
    "t=i" => \$threshold_features,
    "o=i" => \$overlap_features,

    "inc-new" => \$inc_new,
    "s=i" => \$sample_rejects,
    "p=f" => \$reject_proportion,
);

die "No directory!" unless -e "$dir";
$dir =~ s/\/$//g;
my @files = glob "$dir/*";
die "Empty directory!" unless @files;

open FILE1, "<:encoding(UTF-8)", $f_words_file || die $!;
while(<FILE1>)
{
	chomp;
	s/[^a-z']//g; #Strip non-alphabetic characters from function words
	my $key = $_;
	#print "$key ";
	$f_words{$key} = '1'; #Create hash set will all words; value not overly important
}
close FILE1 || die $!;

$f_words{'rawtext'} = 1;
$f_words{'ampamp'} = 1;
$f_words{'amp'} = 1;

foreach my $f (@files) {
    my $line_number = 0;
    my $sec_applications = 0; # 1 if the current line is in the applications section of the file
     
    my $brace_level = 0;
    my $bracket_level = 0;
    my $new_app_brace_level = -inf;
    my $new_app_bracket_level = -inf;
    my $app_number = 0;
    my $in_app = 0; # 1 if the current line is part of an application, 0 otherwise
    my %applications =(); # A hash of all feature vectors for current application
    my %all_experience = (); # A hash of all the experience sections of the applications
    my %app_labels = (); # A hash of all the correct classes, with the app number as the key.
    my $application = ''; # string to store the current application
    my $app_label = '0';

    my $skip_app = 0;

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
	    $line =~ s/\\n/ /g;
	    $line = lc($line);
	    $line =~ s/[^\w\d\s]//g;
	    $line =~ s/^\s+//g;
	    $line =~ s/\s+$//g;
	    $line =~ s/\s+/ /g;

	    foreach my $w (split /\s+/, $line) {
		unless ($f_words{$w}) {
		    print "$w\n";
		}
	    }
	    $app_label = '';
	}

    }
    close FILE || die $!;
}

