# Usage: paste the svm_classify output with the (labelled) example file, and pipe it to this script.
use warnings;
use strict;

my $correct = 0;
my $total = 0;

my $true_pos = 0; # denominator for recall
my $true_neg = 0;

my $correct_pos = 0; # how many positive instances did we get correct? (numerator for precision and recall)
my $labelled_pos = 0; # denominator for precision
my $labelled_neg = 0;

my $job = {};

while (<STDIN>) {
    chomp;
    my ($out,$in,$job_label) = split /\t+/;
    my ($ans,@rest) = split /\s+/,$in; # $out is the svm output, $ans is the correct answer
    my $number = pop @rest; # application number for this particular job
    my $score = $out;
    $out = $out < 0 ? '-1' : '+1';
    next unless $ans == -1 || $ans == 1;

    $job->{$job_label}{$number}{'score'} = $score;
    $job->{$job_label}{$number}{'label'} = $ans;
}

my $sum_average_precision = 0;
my $total_jobs = 0;
J: foreach my $j (sort keys %$job) {
#  $total_jobs++;
  my $rank = 0;
  my $pos_apps = 0;
  my $job_sum_precision = 0;
  foreach my $i (sort {$job->{$j}{$b}{'score'} <=> $job->{$j}{$a}{'score'}} keys %{$job->{$j}}) {
    $rank++;
    if ($job->{$j}{$i}{'label'} == 1) {
	$pos_apps++;
	$job_sum_precision += $pos_apps/$rank;
        #print "Positive number $pos_apps for job '$j' found at rank $rank\n";
        #next J;
    }
  }
  #print "Job '$j' has average precision $job_sum_precision/$pos_apps.\n\n";
  next unless $pos_apps;
  $total_jobs++;
  $sum_average_precision += $job_sum_precision/$pos_apps;
}
printf("Mean Average Precision: %1.1f\n",$sum_average_precision/$total_jobs*100);

