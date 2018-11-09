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
    my @saved_lines_pos = ();
    my @saved_lines_neg = ();
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

	if (($app_label eq '+1' || $app_label eq '-1') && $field =~ /rawText/) {
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

	    $line =~ s/\\n/ /g;
	    $line = lc($line);
	    $line =~ s/[^\w\d\s]//g;
	    $line =~ s/^\s+//g;
	    $line =~ s/\s+$//g;
	    $line =~ s/\s+/ /g;

            if ($app_label eq '+1') {
                push @saved_lines_pos, $line;
            }
            elsif ($app_label eq '-1') {
                push @saved_lines_neg, $line;
	    }

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

    foreach my $l (@saved_lines_pos) {
	my %seen = ();
	foreach my $w (split /\s+/, $l) {
	    if ($jobdesc{$w} && !$f_words{$w}) {
		next if $seen{$w};
		$seen{$w} = 1;
		$apps_with_word{$w}++;
		$pos_with_word{$w}++;
	    }
	}
    }
    foreach my $l (@saved_lines_neg) {
        my %seen = ();
        foreach my $w (split /\s+/, $l) {
            if ($jobdesc{$w} && !$f_words{$w}) {
                next if $seen{$w};
		$seen{$w} = 1;
		$apps_with_word{$w}++;
		$neg_with_word{$w}++;
            }
	}
    }
}

my %information_gain = ();
foreach my $w (sort keys %apps_with_word) {
    $pos_with_word{$w} = 1 unless $pos_with_word{$w};
    $neg_with_word{$w} = 1 unless $neg_with_word{$w};
    my $entropy_before = -plogp($pos_apps/$num_apps) - plogp($neg_apps/$num_apps);
    my $entropy_with_word = -plogp($pos_with_word{$w} / $apps_with_word{$w}) - plogp($neg_with_word{$w} / $apps_with_word{$w});
    my $entropy_without_word = -plogp(($pos_apps - $pos_with_word{$w}) / ($num_apps - $apps_with_word{$w})) - plogp(($neg_apps - $neg_with_word{$w}) / ($num_apps - $apps_with_word{$w}));
    my $entropy_after = ($apps_with_word{$w} / $num_apps) * $entropy_with_word + (($num_apps-$apps_with_word{$w}) / $num_apps) * $entropy_without_word;
    $information_gain{$w} = $entropy_before - $entropy_after;
}

foreach my $w (sort {$information_gain{$b} <=> $information_gain{$a}} keys %information_gain) {
    print "$information_gain{$w}\t$w\n";
}

sub plogp {
    my $p = shift;
    return ($p * log($p)/log(2));
}
