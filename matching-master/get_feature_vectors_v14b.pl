use warnings;
use strict;
use Getopt::Long;
use Time::Piece;
use Time::Local;
use POSIX qw/strftime/;
srand(7); # manually seed the rng for some consistency

#$| = 1;

my $dir = '';
my $count_features = 1;
my $threshold_features = 1;
my $overlap_features = 1;
my $keyword_features = 1;
my $keyword_intersection_features = 1;
my $keybigram_features = 1;
my $education_features_cumulative = 1;
my $education_features_onehot = 1;
my $time_features = 1;
my $ill_formed_feature = 1;
my $rank = 0;
my $f_words_file = 'FunctionWords.txt';
my %f_words = ();
#my %job_description = ();

my $keywords_file = 'keywordFileAccounting';
my $keyword_count = 500;
my %keyword = ();
my @keyword_list = ();

my $keyword_intersection_file = 'intersectionFileAccounting';
my %keyword_intersection = ();
my @keyword_intersection_list = ();

my $keybigrams_file = 'bigramFileAccounting';
my $keybigram_count = 500;
my %keybigram = ();
my @keybigram_list = ();

my $local_keyword_features = 1;
my $jobs_file = 'all_jobs_training';
my $num_jobs++;
my %jobs_containing_word = ();
my $local_keyword_limit = 100;
my $qid = 0;

my $inc_new = 0; # Include unlabeled instances ("new")
my $sample_rejects = 1; # Skip some negative ("reject") instances
my $reject_proportion = 0.75; # Proporation of NEGATIVE ("reject") instances to skip

GetOptions(
    "d=s" => \$dir,
    "fw=s" => \$f_words_file,
    "c=i" => \$count_features,
    "t=i" => \$threshold_features,
    "o=i" => \$overlap_features,
    "k=i" => \$keyword_features,
    "i=i" => \$keyword_intersection_features,
    "l=i" => \$local_keyword_features,
    "b=i" => \$keybigram_features,
    "ec=i" => \$education_features_cumulative,
    "eo=i" => \$education_features_onehot,
    "time=i" => \$time_features,
    "if=i" => \$ill_formed_feature,
    "r=i"  => \$rank,

    "keyword-file=s" => \$keywords_file,
    "keyword-limit=i" => \$keyword_count,
    "keyword-intersection-file=s" => \$keyword_intersection_file,

    "local-keyword-limit=i" => \$local_keyword_limit,

    "keybigram-file=s" => \$keybigrams_file,
    "keybigram-limit=i" => \$keybigram_count,

    "inc-new=i" => \$inc_new,
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
	s/[^a-z']//g;
	my $key = $_;
	#print "$key ";
	$f_words{$key} = '1'; #Create hash set will all words; value not overly important
}
close FILE1 || die $!;
open KEYWORDS, '<', $keywords_file || die $!;
while (<KEYWORDS>) {
    chomp;
    s/^(\s*\d*\s+)//g; # Strip leading numbers and whitespace.
    $keyword{$_} = 1;
    push(@keyword_list, $_);
    last if scalar(keys(%keyword)) >= $keyword_count;
}
close KEYWORDS || die $!;
open KEYWORDS_I, '<', $keyword_intersection_file || die $!;
while (<KEYWORDS_I>) {
    chomp;
    s/^(\s*\d*\s+)//g; # Strip leading numbers and whitespace.
    $keyword_intersection{$_} = 1;
    push(@keyword_intersection_list, $_);
    last if scalar(keys(%keyword_intersection)) >= $keyword_count;
}
close KEYWORDS_I || die $!;
open KEYBIGRAMS, '<', $keybigrams_file || die $!;
while (<KEYBIGRAMS>) {
    chomp;
    s/^(\s*\d*\s+)//g; # Strip leading numbers and whitespace.
    $keybigram{$_} = 1;
    push(@keybigram_list, $_);
    last if scalar(keys(%keybigram)) >= $keybigram_count;
}

open JOBS, '<', $jobs_file || die $!;
while (<JOBS>) {
    chomp;
    $num_jobs++;
    my %seen = ();
    foreach my $w (split /\s+/) {
	next if $seen{$w};
	$seen{$w} = 1;
	$jobs_containing_word{$w}++;
    }
}
close JOBS || die $!;

my %has_highschool = ();
my %has_college = ();
my %has_undergrad = ();
my %has_masters = ();
my %has_doctoral = ();

foreach my $f (@files) {
    #print "In file: $f\n";
    $qid++; #The qid is only of importance for SVM-Rank
    my $line_number = 0;
    my $sec_applications = 0; # 1 if the current line is in the applications section of the file
    my $present_date = get_recent_dates($f);
    #print "Present: $present_date\n";
    my %is_present = (); #feature that indicates that the applicant is working at present
    #print "$present_date\n";     
    my $brace_level = 0;
    my $bracket_level = 0;
    my $new_app_brace_level = -inf;
    my $new_app_bracket_level = -inf;
    my $app_number = 0;
    my $in_app = 0; # 1 if the current line is part of an application, 0 otherwise
    my $in_exp = 0; # 1 if we are currently in the experience section
    my $in_from = 0; # 1 if we are investigating a "from" field
    my $in_to = 0; # 1 if we are investigating a "to" field

    my %applications =(); # A hash of all feature vectors for current application
    my %all_experience = (); # A hash of all the experience sections of the applications
    my %app_labels = (); # A hash of all the correct classes, with the app number as the key.
    my $application = ''; # string to store the current application
    my $app_label = '0';

    %has_highschool = ();
    %has_college = ();
    %has_undergrad = ();
    %has_masters = ();
    %has_doctoral = ();
    my %experience_dates = (); #A hash of all the lengths of time with each
                               #job

    #my $skip_app = 0;

    my %fulltext = (); # Keys are application numbers, values are the full text of the resume.
    my $from_date = 0; #The beginning date for a job
    my $to_date = 0; #The end date of a job

    open FILE, '<', $f || die $!;
    while (<FILE>) {
	chomp;
	my $line = $_;
	$line_number++;

	my $open_braces = () = $line =~ /{/g;
	my $close_braces = () = $line =~ /}/g;
	my $brace_change = $open_braces - $close_braces;
	$brace_level += $brace_change;
	my $ill_formed = 0;
	my $open_brackets = () = $line =~ /\[/g;
	my $close_brackets = () = $line =~ /\]/g;
	my $bracket_change = $open_brackets - $close_brackets;
	$bracket_level += $bracket_change;
	#print "$brace_level $bracket_level $line\n";

	my $app_rawtext = '';

        # Check if a new application is starting.
	if ($sec_applications # check that we are in the applications section 
	    && $brace_change > 0 # check that this line starts a new sub-section
	    && $brace_level == $new_app_brace_level # check that the brace count is correct for a new application
	    && $bracket_level == $new_app_bracket_level # ditto for bracket count
	    ) {
	    $in_app = 1;
	    $app_number++;
	    $is_present{$app_number} = 0;
	    #print "Starting application $app_number on line $line_number.\n";
	    $application = '';
	    $app_label = '?';
	}


        # Applications are divided into "fields" which contain specific types of information.
	my $field = '';
        if ($line =~ /^\s+"(.+)":\s+/) {
            $field = $1;
        }
	if ($in_exp && $line =~ /^\s+\]\s+/){
	    $in_exp = 0; #Right brace ends sections
        }
	if ($field eq 'stage') {
	    if ($line =~ /Rejected/) {
		$app_labels{$app_number} = '-1';
	    }
	    elsif ($line =~ /New/) {
		$app_labels{$app_number} = '0';
	    }
	    else {
		$app_labels{$app_number} = '+1';
	    }
	    next;
	}

        # Save this text in the application string.
	if ($in_app) {
	    if ($bracket_level <= $new_app_bracket_level) {
		$application .= "$line\n";
		$fulltext{$app_number} = $application;
	    }
	    else {
		$application .= "$line " unless $field =~ 'stage';
	    }
	}

        # Check if the current application is ending.
	if ($in_app # check that we are currently in an application                                              
	    && ($brace_change < 0 || $bracket_change < 0) # check that this line ends a sub-section                 
	    && $brace_level == $new_app_brace_level-1 # check that the brace count is correct for a new application
	    && $bracket_level == $new_app_bracket_level # ditto for bracket count
	    ) {
	    $in_app = 0;
	    $applications{$app_number} = $application;
	}
        
        # Certain fields require certain additional actions.
	if ($field eq 'applications') {
            # Start of the applications section of the file.
	    $sec_applications = 1;
	    $new_app_brace_level = $brace_level+1;
	    $new_app_bracket_level = $bracket_level;
	    next;
	}
	elsif ($field eq 'experience'){
	    $in_exp = 1; #We are currently in the experience section
            $experience_dates{$app_number} = ();#Initialize the current hash 
	    $is_present{$app_number} = 0;
	    #May need to be re-worked; present field is inconsistant
	    #print "Experience: $in_exp\n";
	    #print "Line: $line\n";
        }
	elsif($in_exp && $field eq 'from')
	{
	    $in_from = 1; #We are currently in the ``from'' field
	    
	}
	elsif($in_exp && $field eq 'to')
	{
	    $in_to = 1; #We are currently in the ``to'' field
	}
	elsif($in_exp && $field eq 'present')
	{
		if(index($line, 'true') != -1)
		{
			if($present_date ne 'No dates found' && $to_date eq 0)
			#If a present date was found, and the terminating date is not specified
			{
				$is_present{$app_number} = 1;
				#print "From: $from_date\n";
				#print "To: $to_date\n";
				#print "Present: $present_date\n";
				$to_date = $present_date;
			}
		} 
	}
	elsif(($in_from || $in_to) && $field eq '$date')
	{
	    $line = lc($line);
            $line =~ s/\\n//g;
	    $line =~ s/\s+//g;
	    $line = substr($line, 9, 10); #Extract date in YYYY-MM-DD format 
	    if($in_from)
	    {
		$from_date = $line;
		$in_from = 0;

      	    }
	    elsif($in_to)
	    {
		$to_date = $line;
		$in_to = 0;
		if($present_date ne 'No dates found' && $to_date ne '')
		{
                	my $first = Time::Piece->strptime($to_date, "%Y-%m-%d");
                	my $second = Time::Piece->strptime($present_date, "%Y-%m-%d");
                	my $difference = $second - $first;
			if( $difference->days <= 90) 
                	#The assumption is that if the job ended within the last 3 months, it's pretty much present
			{
				$is_present{$app_number} = 1;
			}
		}

	    }

        }

	elsif($in_exp && $field eq 'order')
	{
	    if($from_date eq '')
	    {
		$from_date = 0;
	    }
	    if($to_date eq '')
	    {
		$to_date = 0;
	    }
		#print "Application: $app_number\n";
		my $num_keys = (keys %{$experience_dates{$app_number}});
		#print "Num keys: $num_keys\n";
		#print "$_ $experience_dates{$app_number}{$_}\n" for (keys %{$experience_dates{$app_number}});
	    if($from_date eq 0 || $to_date eq 0) #Can't find to or from
            {
		$ill_formed = 1;
		$from_date = 0;
		$to_date = 0;
		$experience_dates{$app_number}{$num_keys} = 'Ill';
		#print "Ill\n";
            }
            else
            {
                my $first = Time::Piece->strptime($from_date, "%Y-%m-%d");
                my $second = Time::Piece->strptime($to_date, "%Y-%m-%d");
                my $difference = $second - $first;
		if ($difference < 0)
		{
			$ill_formed = 1;
			$from_date = 0;
			$to_date = 0;
			$experience_dates{$app_number}{$num_keys} = 'Ill';
		#	print "Ill\n";
		}
		else
		{
			#print "$second is ", int($difference->days), " days since $first\n";
			$experience_dates{$app_number}{$num_keys} = $difference->days;
			$from_date = 0;
			$to_date = 0;
		#	print "Difference:", int($difference->days), "\n";
		}
            }
	}
	
	elsif ($field eq 'degree') {
	    $line = lc($line);
	    $line =~ s/\\n//g;
	    $line =~ s/[^a-zA-Z\s]//gi;

	    if ($line =~ /high school/i | $line =~ /ged/i | $line =~ /general educational development/i | $line =~ /diploma/i | $line =~ /secondary school/i | $line =~ /graduate/i | $line =~ /grade 12/i | $line =~ /ossd/i) {
		$has_highschool{$app_number} = 1;
	    }
            elsif ($line =~ /certificate/i | $line =~ /college/i | $line =~ /college diploma/i) {
		$has_college{$app_number} = 1;
            }
            elsif ($line =~ /bachelor/i | $line =~ /bsc/i | $line =~ /[^m]ba/i | $line =~ /ab/i | $line =~ /undergraduate/i) {
		$has_undergrad{$app_number} = 1;
            }
            elsif ($line =~ /master/i | $line =~ /msc/i | $line =~ /ma/i | $line =~ /mba/i) {
		$has_masters{$app_number} = 1;
            }
            elsif ($line =~ /doctor/i | $line =~ /phd/i) {
		$has_doctoral{$app_number} = 1;
            }
	}
	elsif ($field eq 'job')
	{
	    my $l = $line;
	    $l =~ s/\\n/ /g;
	    $l = lc $l;
	    $l =~ s/[^\w\d\s]/ /g;
	    $l =~ s/^\s+//g;
	    $l =~ s/\s+$//g;
	    $l =~ s/\s+/ /g;
	    $l =~ s/^\s*job\s*//g;

	    my $job_description = {};
	    my %count = ();
	    foreach my $w (split(/\s+/,$l)) 
	    {
		$count{$w}++;
		unless(exists($f_words{$w}))
		{
		    $job_description->{$w} = '1';
		}
	    }
	    my %tfidf = ();
	    foreach my $w (sort keys %count) {
		no warnings 'uninitialized';
		$tfidf{$w} = ( ($count{$w}) * log(($num_jobs+1)/($jobs_containing_word{$w}+1)) );
	    }
	    my @local_keywords = ();
	    foreach my $w (sort {$tfidf{$b} <=> $tfidf{$a}} keys(%tfidf)) {
		push @local_keywords, $w;
		last if @local_keywords >= $local_keyword_limit;
	    }
	    
	    foreach my $s (sort {$a <=> $b} keys %applications)
	    {
		next unless defined($app_labels{$s});
		if ($app_labels{$s} == 0 && $inc_new == 0) {
		    next;
		}
		elsif ($app_labels{$s} == -1 && $sample_rejects && rand() < $reject_proportion) {
		    next;
		}

		#foreach my $key (keys %experience_dates)
		#{
		#	my %exp2 = %{$experience_dates{$key}};
		#	foreach my $key2 (keys %exp2)
		#	{
		#		print "$key $experience_dates{$key}{$key2}\n";
		#	}
		#}
		my $feature_vector = app_to_features($qid, $s, $applications{$s}, $app_labels{$s},
                    $job_description, $fulltext{$s}, $is_present{$s}, \@local_keywords, \%experience_dates);
		#print "Actually Present: $is_present\n";
		print "$feature_vector # application $s\t$f\n";
	    }
	    %applications = ();#clear hashes
	    %app_labels = ();
	    
	}
    }
    close FILE || die $!;
}

sub app_to_features {
    my ($qid, $app_number, $application, $app_label, $job_description, $rawtext, $present_feature, $local_keywords, $experience) = @_;
    my $app_education = 0;
    my $app_experience = 0;
    my @descriptions = ();
    #print "We think it's present: $present_feature\n";
    $rawtext =~ s/\\n/ /g;
    $rawtext = lc($rawtext);
    $rawtext =~ s/[^\w\d\s]/ /g;
    $rawtext =~ s/^\s+//g;
    $rawtext =~ s/\s+$//g;
    $rawtext =~ s/\s+/ /g;

    my %found = ();
    my %found_bigram = ();
    if ($rawtext) {
	my @words = split /\s+/, $rawtext;
	no warnings 'uninitialized';
	$found{$words[0]}++;
	for (my $i = 1; $i < @words; $i++) {
	    my $v = $words[$i-1];
	    my $w = $words[$i];
            no warnings 'uninitialized';
            $found{$w}++;
	    $found_bigram{"$v $w"}++;
        }
    }

    foreach my $l (split(/\n+/,$application)) {
	if ($l =~ /^\s*"education":/) {
	    my $count = () = $l =~ /"date":/g;
	    $app_education = $count;
	}
	if ($l =~ /^\s*"experience":/) {
	    my $count = () = $l =~ /"date":/g;
	    $app_experience = $count;
	    @descriptions = ($l =~ /"description"[^}]*}/g); # Read all descriptions into the array.
	}
    }

    my @features;
    if ($count_features) {
	push @features, $app_education;
	push @features, $app_experience;
    }
    if ($threshold_features) {
	for (my $i = 1; $i <= 10; $i++) {
	    if ($app_education >= $i) {
		push @features, '1';
	    }
	    else {
		push @features, '0';
	    }
	}
        for (my $i = 1; $i <= 10; $i++) {
            if ($app_experience >= $i) {
                push @features, '1';
            }
	    else {
		push @features, '0';
	    }
        }
    }
    if ($overlap_features) {
	my %exp_description = ();
	foreach my $d (@descriptions) {
            $d =~ s/\\n/ /g;
            $d = lc($d);
            $d =~ s/[^\w\d\s]//g;
            $d =~ s/^\s+//g;
            $d =~ s/\s+$//g;
            $d =~ s/\s+/ /g;

	    foreach my $l (split(/\s+/,$d)) {
		$l = lc $l;
		if (exists $job_description->{$l} && !exists $f_words{$l}) {
		    #print "Application has keyword $l.\n";
		    $exp_description{$l} = '1';
		    #print "$l\n";
		}
	    }
	}
	
	my $overlap_count = keys %exp_description;
	push @features, $overlap_count;
	for (my $i = 1; $i <= 10; $i++) {
	    if ($overlap_count >= $i) {
		push @features, '1';
	    }
	    else {
		push @features, '0';
	    }
	}
    }

    if ($keyword_features) {
	foreach my $k (@keyword_list) {
	    if ($found{$k}) {
		#push @features, $found{$k};
		push @features, 1;
	    }
	    else {
		push @features, 0;
	    }
	}
    }

    if ($keyword_intersection_features) {
        foreach my $k (@keyword_intersection_list) {
            if ($found{$k} && $job_description->{$k}) {
                #push @features, $found{$k};
                push @features, 1;
            }
            else {
                push @features, 0;
            }
        }
    }

    if ($keybigram_features) {
	foreach my $b (@keybigram_list) {
	    if ($found_bigram{$b}) {
		push @features, '1';
	    }
	    else {
		push @features, '0';
	    }
	}
    }

    my $local_keyword_count = 0;
    if ($local_keyword_features) {
        foreach my $k (@$local_keywords) {
            if ($found{$k}) {
                push @features, 1;
		$local_keyword_count++;
            }
            else {
                push @features, 0;
            }
        }
	push @features, $local_keyword_count;
    }

    my $sum = 0;
    my $total_jobs = 0;#This number will only include jobs for which we could extract dates
    my $shortest = 100000000;
    my $longest = 0;
    my $most_recent = 0;
    my $length = 0;
    my $ill_feature = 0;
    if($time_features)
    {
		#print "Application: $app_number\n";
		my %local_experience = %{$experience};
		my %current_experience = ();
		if($local_experience{$app_number})
		{
			%current_experience = %{$local_experience{$app_number}};
		}

	#print "$_ $current_experience{$_}\n" for (keys %current_experience);
	
        foreach my $key (keys %current_experience)
	{
		#print "Application: $app_number\n";
		#print "ID: $key\n";
		$length = $current_experience{$key};
		#print "Length: $length\n";
		if ($key eq 0)
		{	
			$most_recent = $length;
			if($length eq 'Ill')
			{
				$most_recent = 0;
			}
		}
		if ($length eq 'Ill')
		{
			$ill_feature = 1;
		}
		else
		{
			$total_jobs++;
			$sum += $length;
			if($length > $longest)
			{
				$longest = $length;
			}
			if($length < $shortest)
			{
				$shortest = $length;
			}
		}
	}

    	if ($total_jobs eq 0)
	    {
		$total_jobs = 1;
		$shortest = 0;
    	}
    	
        my $average = $sum / $total_jobs;
	#print "Most recent: $most_recent\n";
	#print "Longest: $longest\n";
	#print "Shortest: $shortest\n";
	#print "Average: $average\n";
	#print "Sum: $sum\n";
	#print "Most recent begins at: $#features\n";
	push @features, ($most_recent < 30 ? 1 : 0);#approx 1 month
	push @features, (($most_recent < 60 && $most_recent >=30) ? 1 : 0);#approx 2 months
	push @features, (($most_recent < 90 && $most_recent >=60) ? 1 : 0);#approx 3 months
	push @features, (($most_recent < 120 && $most_recent >=90)? 1 : 0);#approx 4 months
	push @features, (($most_recent < 150 && $most_recent >=120)? 1 : 0);#approx 5 months
	push @features, (($most_recent < 180 && $most_recent >=150)? 1 : 0);#approx 6 months
	push @features, (($most_recent < 210 && $most_recent >=180)? 1 : 0);#approx 7 months
	push @features, (($most_recent < 240 && $most_recent >=210)? 1 : 0);#approx 8 months
	push @features, (($most_recent < 270 && $most_recent >=240)? 1 : 0);#approx 9 months
	push @features, (($most_recent < 300 && $most_recent >=270)? 1 : 0);#approx 10 months
	push @features, (($most_recent < 330 && $most_recent >=300)? 1 : 0);#approx 11 months 
	push @features, (($most_recent < 360 && $most_recent >=330)? 1 : 0);#approx 12 months 
	push @features, ($most_recent >= 360 ? 1 : 0);
	
	#print "Shortest begins at: $#features\n";
	
	push @features, ($shortest < 30 ? 1 : 0);#approx 1 month
	push @features, (($shortest < 60 && $shortest >=30) ? 1 : 0);#approx 2 months
	push @features, (($shortest < 90 && $shortest >=60) ? 1 : 0);#approx 3 months
	push @features, (($shortest < 120 && $shortest >=90)? 1 : 0);#approx 4 months
	push @features, (($shortest < 150 && $shortest >=120)? 1 : 0);#approx 5 months 
	push @features, (($shortest < 180 && $shortest >=150)? 1 : 0);#approx 6 months
	push @features, (($shortest < 210 && $shortest >=180)? 1 : 0);#approx 7 months
	push @features, (($shortest < 240 && $shortest >=210)? 1 : 0);#approx 8 months
	push @features, (($shortest < 270 && $shortest >=240)? 1 : 0);#approx 9 months
	push @features, (($shortest < 300 && $shortest >=270)? 1 : 0);#approx 10 months
	push @features, (($shortest < 330 && $shortest >=300)? 1 : 0);#approx 11 months
	push @features, (($shortest < 360 && $shortest >=330)? 1 : 0);#approx 12 months
	push @features, ($shortest >= 360 ? 1 : 0);

	#print "Longest begins at: scalar $#features\n";
	push @features, ($longest < 30 ? 1 : 0);#approx 1 month
	push @features, (($longest < 60 && $longest >=30) ? 1 : 0);#approx 2 months
	push @features, (($longest < 90 && $longest >=60) ? 1 : 0);#approx 3 months
	push @features, (($longest < 120 && $longest >=90)? 1 : 0);#approx 4 months
	push @features, (($longest < 150 && $longest >=120)? 1 : 0);#approx 5 months
	push @features, (($longest < 180 && $longest >=150)? 1 : 0);#approx 6 months
	push @features, (($longest < 210 && $longest >=180)? 1 : 0);#approx 7 months
	push @features, (($longest < 240 && $longest >=210)? 1 : 0);#approx 8 months
	push @features, (($longest < 270 && $longest >=240)? 1 : 0);#approx 9 months
	push @features, (($longest < 300 && $longest >=270)? 1 : 0);#approx 10 months
	push @features, (($longest < 330 && $longest >=300)? 1 : 0);#approx 11 months
	push @features, (($longest < 360 && $longest >=330)? 1 : 0);#approx 1 year 
	push @features, ($longest >= 360 ? 1 : 0);
	
	#print "Average begins at: scalar $#features\n";
	push @features, ($average < 30 ? 1 : 0);#approx 1 month
	push @features, (($average < 60 && $average >=30) ? 1 : 0);#approx 2 months
	push @features, (($average < 90 && $average >=60) ? 1 : 0);#approx 3 months
	push @features, (($average < 120 && $average >=90)? 1 : 0);#approx 4 months
	push @features, (($average < 150 && $average >=120)? 1 : 0);#approx 5 months
	push @features, (($average < 180 && $average >=150)? 1 : 0);#approx 6 months
	push @features, (($average < 210 && $average >=180)? 1 : 0);#approx 7 months
	push @features, (($average < 240 && $average >=210)? 1 : 0);#approx 8 months 
	push @features, (($average< 270 && $average >=240)? 1 : 0);#approx 9 months
	push @features, (($average < 300 && $average >=270)? 1 : 0);#approx 10 months
	push @features, (($average < 330 && $average >=300)? 1 : 0);#approx 11 months
	push @features, (($average < 360 && $average >=330)? 1 : 0);#approx 12 months
	push @features, ($average >= 360 ? 1 : 0);
        
	
	#print "Sum begins at: scalar $#features\n";
	
	push @features, ($sum < 200 ? 1 : 0);#approx 6 months
	push @features, (($sum < 400 && $sum >=200) ? 1 : 0);#approx 1 year
	push @features, (($sum < 600 && $sum >=400) ? 1 : 0);#1.5 year
	push @features, (($sum < 800 && $sum >=600)? 1 : 0);#approx 2 years
	push @features, (($sum < 1000 && $sum >=800)? 1 : 0);#approx 2.5 years
	push @features, (($sum < 1200 && $sum >=1000)? 1 : 0);#approx 3 years
	push @features, (($sum < 1400 && $sum >=1200)? 1 : 0);#approx 3.5 years
	push @features, (($sum < 1600 && $sum >=1400)? 1 : 0);#approx 4 years
	push @features, (($sum < 1800 && $sum >=1600)? 1 : 0);#approx 4.5 years
	push @features, (($sum < 2000 && $sum >=1800)? 1 : 0);#approx 5 years
	push @features, (($sum < 2200 && $sum >=2000)? 1 : 0);#approx 5.5 years
	push @features, (($sum < 2400 && $sum >=2200)? 1 : 0);#approx 6 years
	push @features, ($sum >= 2400 ? 1 : 0);
        
	

	push @features, $present_feature;
	if($ill_formed_feature)
	{
		push @features, $ill_feature;
	}
    }
    if ($education_features_cumulative) {
	#print "Ed\n";
	push @features, ($has_highschool{$app_number} ? 1 : 0);
	push @features, ($has_college{$app_number} ? 1 : 0);
	push @features, ($has_undergrad{$app_number} ? 1 : 0);
	push @features, ($has_masters{$app_number} ? 1 : 0);
	push @features, ($has_doctoral{$app_number} ? 1 : 0);
    }

    if ($education_features_onehot) {
	#print "Ed1h\n";
	if ($has_doctoral{$app_number}) {
	    push @features, (0,0,0,0,1);
	}
	elsif ($has_masters{$app_number}) {
	    push @features, (0,0,0,1,0);
	}
        elsif ($has_undergrad{$app_number}) {
	    push @features, (0,0,1,0,0);
	}
        elsif ($has_college{$app_number}) {
	    push @features, (0,1,0,0,0);
	}
        elsif ($has_highschool{$app_number}) {
	    push @features, (1,0,0,0,0);
	}
	else {
	    push @features, (0,0,0,0,0);
	}
    }

    my $feature_vector = features_to_vector($qid, $app_label, @features);
    return $feature_vector;
}

sub features_to_vector {
    my ($qid, $app_label, @features) = @_;
    my @elements = ();
    push @elements, $app_label;
    if($rank)
    {
    	push @elements, "qid:$qid";
    }
    for (my $i = 1; $i <= @features; $i++) {
	if($features[$i -1] != 0)
	{
		push @elements, "$i:$features[$i-1]";
	}
    }
    return join(' ', @elements);
}

sub get_recent_dates {
    my ($file_to_investigate) = @_;


    # For dates structured as: Month DD, YYYY
    my $date_regex_1 = qr/(Janu?a?r?y?|Febr?u?a?r?y?|Marc?h?|Apri?l?|May|June?|July?|Augu?s?t?|Septe?m?b?e?r?|Octo?b?e?r?|Nove?m?b?e?r?|Dece?m?b?e?r?)\s(\d\d?)(st|nd|rd|th)?,?\s?(\d\d\d\d)/;

    # For dates structured as: DD Month YYYY
    my $date_regex_2 = qr/(\d\d?)\s(January|February|March|April|May|June|July|August|September|October|November|December)\s(\d\d\d\d)/;

    # For dates structured as: Month YYYY
    my $date_regex_3 = qr/(January|February|March|April|May|June|July|August|September|October|November|December)\s(\d\d\d\d)/;

    my %month2num = qw(January 0 February 1 March 2 April 3 May 4 June 5
                   July 6 August 7 September 8 October 9 November 10 December 11
                   Jan 0 Feb 1 Mar 2 Apr 3 May 4 Jun 5 Jul 6 Aug 7 Sept 8 Oct 9 Nov 10 Dec 11);

    #my @files = glob "$file_to_investigate";
    #die "Empty directory!" unless @files;

    #open my $output_file, '>', './output' || die $!;

    #foreach my $f (@files) {
	#print "$file_to_investigate\n";
        my $in_cover_letter = 0; # 1 if the current line is part of a cover letter. 0 otherwise.
        my $most_recent_time = 0; # Stores the most recent date found for a file as a timestamp
        my $most_recent_date = ''; # Stores the most recent date found for a file in a readable format
        my $month_var = -1;
        my $day_var = -1;
        my $year_var = -1;
        my $time_var = -1;

        open FILE2, '<', $file_to_investigate || die $!;
        while (my $line = <FILE2>) {
                chomp $line;
                # Check if cover letter field is starting
                if ($line =~ /^\s+"coverLetter":\s+/) {
                        $in_cover_letter = 1;
                }

                if ($in_cover_letter) {
                        # Check if the cover letter field is ending
                        if ($line =~ /[^\\]",/) {
                                $in_cover_letter = 0;
                        }

                        # Search for a date in this line
                        if ($line =~ $date_regex_1) {

                                $month_var = $month2num{$1};
                                $day_var = $2;
                                $year_var = $4;

                        } elsif ($line =~ $date_regex_2) {

                                $day_var = $1;
                                $month_var = $month2num{$2};
                                $year_var = $3;

                        } elsif ($line =~ $date_regex_3) {

                                $day_var = 0;
                                $month_var = $month2num{$1};
                                $year_var = $2;
                        }

                        # Check if date is valid. If it is, convert to timestamp. Otherwise ignore this date.
			if(!defined $month_var)
			{
				$month_var = -1;
			}
                        if ($day_var >= 1 && $day_var <= 31 && $month_var >= 0 && $month_var <= 11) {
				$day_var = $day_var - 1;
				if($day_var eq 0)
				{
					$day_var = 1;
				}#Hacky fix to February out of leap year problem
                                $time_var = timelocal(0, 0, 0, $day_var, $month_var, $year_var);

                                if ($time_var > timelocal(localtime)) {
                                        next;
                                }

                        } else {
                                next;
			}

                        # Store the most recent time and reset values
                        if ($time_var > $most_recent_time) {

                                $most_recent_time = $time_var;
                                $month_var = -1;
                                $day_var = -1;
                                $year_var = -1;
                                $time_var = -1;
                        }

                }

        }
        # Convert the timestamp to a human readable date
        if ($most_recent_time > 0) {
                $most_recent_date = strftime('%Y-%m-%d', localtime($most_recent_time));
        } else {
                $most_recent_date = "No dates found";
        }

        #print $output_file "$most_recent_date\n";

	close FILE2 || die $!;
	#close $output_file || die $!;
        return $most_recent_date;



	#print "Done\n";

}
