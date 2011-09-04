#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Std;
use Time::HiRes qw(gettimeofday tv_interval);
use Data::Dumper;

$SIG{'INT'}=\&sighandler;
$SIG{'TERM'}=\&sighandler;

my %options;
getopt('n:b:o:', \%options);

print "timing-attack-checker v1.0 http://pentestmonkey.net/tools/timing-attack-checker\n\n";
my $usage = "Usage: timing-attack-check.pl [ options ] 'cmd1' 'cmd2' ['cmd3' ...]

options are:
  -n N      Number of times to run the commands
  -o file   File to write tab delimited data to

Example:
  timing-attack-check.pl 'login.pl -u knownuser -p x' 'login.pl -u notexist -p x'
\n";

my $iterations = 100;
my $batchsize = 1; # not implemented yet
my $outputfile = undef;
my %results;
while (my $command = shift) {
	$results{$command} = {};
	$results{$command}{runtimes} = [];
}

if (scalar(keys %results) == 0) {
	print $usage;
	exit(0);
}

if (scalar(keys %results) == 1) {
	print "[E] At least two commands need to be given\n";
	print $usage;
	exit(1);
}

$iterations = $options{'n'} if (defined($options{'n'}));
$batchsize  = $options{'b'} if (defined($options{'b'}));
$outputfile = $options{'o'} if (defined($options{'o'}));

for my $n (0..$iterations-1) {
	for my $cmd (keys %results) {
		$results{$cmd}{runtimes}[$n] = timeit($cmd);
	}
}

for my $cmd (keys %results) {
	my @times = @{$results{$cmd}{runtimes}};
	printf "=================================================\n";
	printf "Results for: $cmd\n";
	printf "Average time: %s\n", average(@times);
	printf "Minimum time: %s\n", min(@times);
	printf "Maximum time: %s\n", max(@times);
	printf "Standard deviation: %s (i.e. 68%% of times within 1 sd, 95%% within 2 sd)\n", stddev(@times);
	printf "Was fastest on %s out of %s occassions (%s%% of the time)\n", fastestcount($cmd), $iterations, 100*(fastestcount($cmd)/$iterations);
	printf "Was slowest on %s out of %s occassions (%s%% of the time)\n", slowestcount($cmd), $iterations, 100*(slowestcount($cmd)/$iterations);
}
printf "=================================================\n";

if (defined($outputfile)) {
	print "[+] Saving tab-delimited data to $outputfile\n";
	open OUT, ">$outputfile" or die "[E] Can't open $outputfile for writing: $!\n";
	print OUT join "\t", keys %results;
	print OUT "\n";
	for my $n (0..$iterations-1) {
		print OUT join "\t", map { $results{$_}{runtimes}[$n]} sort keys %results;
		print OUT "\n";
	}
}

sub timeit {
	my $cmd = shift;
	dprint("Running command: $cmd");

	# Hide the output of the command we run
	open my $oldout, ">&STDOUT"     or die "Can't dup STDOUT: $!";
	open my $olderr, ">&STDERR"     or die "Can't dup STDERR: $!";
	open STDOUT, '>', "/dev/null" or die "Can't redirect STDOUT: $!";
	open STDERR, '>', "/dev/null" or die "Can't redirect STDERR: $!";

	my $starttime = [gettimeofday];
	system($cmd);
	my $endtime = [gettimeofday];
	my $runtime = tv_interval($starttime, $endtime);

	open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";
	open STDERR, ">&", $olderr or die "Can't dup \$olderr: $!";

	dprint("Command took $runtime secs");
	return $runtime;
}

sub fastestcount {
	my $cmd = shift;

	my $count = 0;
	for my $index (0..$iterations-1) {
		if (wasfastest($index, $cmd)) {
			$count++;
		}
	}

	return $count;
}

sub wasfastest {
	my ($index, $cmd) = @_;

	my @times = ();
	for my $c (keys %results) {
		push(@times, $results{$c}{runtimes}[$index]);
	}

	if (min(@times) == $results{$cmd}{runtimes}[$index]) {
		return 1;
	} else {
		return 0;
	}
}

sub slowestcount {
	my $cmd = shift;

	my $count = 0;
	for my $index (0..$iterations-1) {
		if (wasslowest($index, $cmd)) {
			$count++;
		}
	}

	return $count;
}

sub wasslowest {
	my ($index, $cmd) = @_;

	my @times = ();
	for my $c (keys %results) {
		push(@times, $results{$c}{runtimes}[$index]);
	}

	if (max(@times) == $results{$cmd}{runtimes}[$index]) {
		return 1;
	} else {
		return 0;
	}
}

sub dprint {
	my $message = shift;
	print "[D] $message\n";
}

sub sighandler {
	print "[+] Caught signal.  Quitting.\n";
	exit(1);
}

sub min {
	my @numbers = @_;
	return (sort @numbers)[0];
}

sub max {
	my @numbers = @_;
	return (sort @numbers)[-1];
}

sub stddev {
	my @numbers = @_;
	my $average = average(@numbers);

	my $deviation2sum = 0; # sum of mean devation^2
	foreach my $n (@numbers) {
		$deviation2sum += ($average - $n)**2;
	}
	my $averagedeviation2sum = $deviation2sum / (scalar @numbers);
	
	return sqrt($averagedeviation2sum);
}

sub average {
	my @numbers = @_;
	my $sum = 0;
	foreach my $n (@numbers) {
		$sum += $n;
	}
	return $sum / (scalar @numbers);
}

