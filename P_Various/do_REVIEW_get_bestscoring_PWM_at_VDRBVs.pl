#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Getopt::Long;

#6/4/2016
#Following the latest batch of comments from Chris and Wilfried, I want to :
#1-associate each VDR-BV hitting a VDR-RXR motif with strong score, and move aside
#2-for all remaining VDR-BVs, what is the strongest motif (by score) being hit? associate to that

#in the end you want a plot mapping every VDR-BV to the BEST motif they hit.
#All the bottom code is useless atm. Need to rewrite.

#Inputs: all the enriched VDR-BV (not VDR-rBV).ris files with a pwm interval for each of the 43K
#main loop: for each VDR-BV:
#does the VDR-BV intersect a RXR::VDR with pscanchip > 0.8?
#yes: store in hash with labels
#no: check all ris files. For all the pwms for which an intersection is found, check score (KEEP THRESHOLD AT 0.8?)
#store best scoring  in hash with labels 

#I ASSUME the entries in the ris file are sorted by decreasing score by PScanChIP
#Therefore I fill an array with the corrected entries from the .ris file. I will then search the vdr bv against each array entry
#breaking at the first intersection, which should be the one with higher score


my $BEDTOOLS = `which bedtools`; chomp $BEDTOOLS;
#my $RSCRIPT = `which RRscript`; chomp $RSCRIPT;
#my $CHROMSIZES = '/net/isi-scratch/giuseppe/indexes/chrominfo/hg19.chrom_simple.sizes';

#my $TEMP_PATH = "C:/Users/Giuseppe/Desktop/REVIEW_temp/DATA/";
#my $IN_VDRBV = $TEMP_PATH . "Output_noDBRECUR.vcf";
#my $PWM_FILE = $TEMP_PATH . "Processed_PFMs_jaspar_FUNSEQ_INPUT.txt";

my $IN_VDRBV = "/net/isi-scratch/giuseppe/VDR/ALLELESEQ/funseq2/out_allsamples_plus_qtl_ancestral/Output_noDBRECUR.vcf";
#my $IN_VDRBV_BED = '/net/isi-scratch/giuseppe/VDR/ALLELESEQ/funseq2/out_allsamples_plus_qtl_ancestral/PSCANCHIP_motifs/Output_noDBRECUR.bed'; 
my $PWM_FILE = "/net/isi-scratch/giuseppe/VDR/ALLELESEQ/funseq2/out_allsamples_plus_qtl_ancestral/PSCANCHIP_motifs/Processed_PFMs_jaspar_FUNSEQ_INPUT.txt";

my $INPUT_RIS_DIR;
my $MIN_SCORE;

#GLOBALS
#1 vdr-bvs
my %VDRBV_coords;
#this will be checked against the ris intervals and intersecting items will be removed
#2
#contains the jaspar representation of the pws to get the correct length
my %JASPAR_MOTIF; 
#3 result structure
#coord->associated_pwm->score
my %RESULTS;

#If the best has same score for many motifs? Take the LONGEST

GetOptions(
        'm=s'		=>\$INPUT_RIS_DIR,          
        's=f'		=>\$MIN_SCORE,   
);
#temp
$INPUT_RIS_DIR = "/net/isi-scratch/giuseppe/VDR/ALLELESEQ/funseq2/out_allsamples_plus_qtl_ancestral/PSCANCHIP_motifs/VDR-BV";
#$INPUT_RIS_DIR = $TEMP_PATH . 'RIS';
$MIN_SCORE = 0.8;
my $RXR_VDR_RIS = "Pscanchip_hg19_bkgGM12865_Jaspar_VDRBVs_RXRA-VDR_MA0074.1_sites.ris";
my $RXR_VDR_PATH = $INPUT_RIS_DIR . '/' . $RXR_VDR_RIS;


my $USAGE = "\nUSAGE: $0 -m=<VDRBV_RIS_DIR> -t=<MIN_SCORE>\n" .
			"<VDRBV_RIS_DIR> ris file from PscanChip\n" .
			"(opt)<MIN_SCORE> min PscanChip score to consider (default=undef)\n";
			
unless($INPUT_RIS_DIR){
	print $USAGE;
	exit -1;
}
print "Minimum PScanChIP score set to $MIN_SCORE\n" if ($MIN_SCORE);

#Get all VDR-BVs from file-----------------------------------------------------------------
#get_vdrbvs_from_file($IN_VDRBV, \%VDRBV_coords);
#my $VDRBV_initial = keys %VDRBV_coords;

#Get the motif length from the encode representations of the motif---------------------
get_motif_lengths($PWM_FILE, \%JASPAR_MOTIF);

#RXR:VDR----------
#1 Build pwm ID
my ($motif_string, $full_motif_id, $motif_length) = get_pwm_id($RXR_VDR_RIS);
print STDERR "The length of the motif: $full_motif_id according to the JASPAR PWM is $motif_length\n";
#2 write bed of ris intervals
my $tmp_ris_bed       = $INPUT_RIS_DIR . '/TMP_from_ris_'  . $motif_string . '.bed';
my $tmp_intersect_bed = $INPUT_RIS_DIR . '/TMP_intersect_' . $motif_string . '.bed'; 
write_ris_to_bed_file($RXR_VDR_PATH, $tmp_ris_bed, $motif_length);
system "$BEDTOOLS intersect -c -a $IN_VDRBV -b $tmp_ris_bed > $tmp_intersect_bed";
#in column 9 there is either 1 or zero

#
#bedtools intersect
#filter those which intersect and put in RESULT
#output bed of those that don't intersect


#OLD
#2. Fill array of pwm intervals from ris------------------------------------------------------
#my @ris_array = get_ris_intervals($RXR_VDR_PATH, $motif_length);
#3. Check the vdr-bvs against the RXR:VDR ris:------------------------------------------------
#-for each line in bed, see if vdrbv is in interval.
#If so, remove it from main hash and place in result hash
#print "Working on $full_motif_id:\n";
#foreach my $item (keys %VDRBV_coords){
#	my $best_scoring_intersecting_pwm = check_vdrbv_intersects_pwm_interval($item, @ris_array);
#	if ($best_scoring_intersecting_pwm){
#		print STDERR '.';
#		my ($chr, $start, $stop, $score) = split("\t", $best_scoring_intersecting_pwm);
#		#TODO you might want to save more than the score.
#		$RESULTS{$item}{$motif_string} = $score;
#		delete($VDRBV_coords{$item});
#	}
#}
#print "\n";
#print "Initial VDR-BVs: $VDRBV_initial\n";
#my $VDRBV_left = keys %VDRBV_coords;
#print "VDR-BV left after assigning to $full_motif_id at min score thrs: $MIN_SCORE: $VDRBV_left\n";

#
#ALL PWM RIS----------
#
#Here I will need an intermediate hash, with
#pos -> pmw_id1 -> score1
#   |
#   |_> pwm_id2 -> score2
#For each of these positions, I will have to choose the best scoring pwm_id. Also, if two or more have the same score, I pick the largest PWM

#1st pass: label each vdrbv with the best instanes of all the pwm(s) they fall in
my %results_allpwms;
chdir $INPUT_RIS_DIR;
my @files = <Pscanchip_hg19*.ris>;
foreach my $RIS_FILE (@files){
	next if ($RIS_FILE eq $RXR_VDR_RIS);
	my $RIS_FILE_PATH = $INPUT_RIS_DIR  . '/' . $RIS_FILE;
	
	#1. Build pwm ID------------------------------------------------------------------------------
	my ($motif_string, $full_motif_id, $motif_length) = get_pwm_id($RIS_FILE);
	print STDERR "The length of the motif: $full_motif_id according to the JASPAR PWM is $motif_length\n";
	#2. Fill array of pwm intervals from ris------------------------------------------------------
	my @ris_array = get_ris_intervals($RIS_FILE_PATH, $motif_length);
	#3. Check the vdr-bvs against the ris:--------------------------------------------------------
	print "Working on $full_motif_id:\n";
	foreach my $vdrbv (keys %VDRBV_coords){
		my $best_scoring_intersecting_pwm = check_vdrbv_intersects_pwm_interval($vdrbv, @ris_array);
		if ($best_scoring_intersecting_pwm){
			print STDERR '.';
			my ($chr, $start, $stop, $score) = split("\t", $best_scoring_intersecting_pwm);
			$results_allpwms{$vdrbv}{$motif_string}{'SCORE'}      = $score;
			$results_allpwms{$vdrbv}{$motif_string}{'PWM_LENGTH'} = $motif_length;
			delete($VDRBV_coords{$vdrbv});
		}
	}
	print "\n";		
}


#for every position, choose one pwm
#criteria:
#if 1 pwm, keep it
#if 2 or more, get highest score
#if score same get longest

foreach my $vdrbv_pos (keys %results_allpwms){
	my $number_of_pwms = keys %{$results_allpwms{$vdrbv_pos}};
	
	if($number_of_pwms == 1){
		foreach my $this_pwm (keys %{$results_allpwms{$vdrbv_pos}}){
			$RESULTS{$vdrbv_pos}{$this_pwm} = $results_allpwms{$vdrbv_pos}{'SCORE'};
		}
		next;
	}
	
	my $candidate_score = 0;
	my $candidate_length = 0;
	my $candidate_pwm = '';
	
	foreach my $this_pwm (keys %{$results_allpwms{$vdrbv_pos}}){
		my $this_score = $results_allpwms{$vdrbv_pos}{'SCORE'};
		my $this_length =  $results_allpwms{$vdrbv_pos}{'PWM_LENGTH'};
		if($this_score > $candidate_score){
			$candidate_pwm = $this_pwm;
			$candidate_score = $this_score;
			$candidate_length = $this_length;
		}elsif($this_score == $candidate_score){
			if($this_length >= $candidate_length){
				$candidate_pwm = $this_pwm;
				$candidate_score = $this_score;
				$candidate_length = $this_length;					
			}else{
				next;
			}
		}else{
			next;
		}
	}
	$RESULTS{$vdrbv_pos}{$candidate_pwm} = $candidate_score;
}

	#foreach my $motif_pwm (keys %{$results_allpwms{$vdrbv_coords}}){
#		print $counter, ":\t", $vdrbv_coords, "\t", $motif_pwm, "\t", $results_allpwms{$vdrbv_coords}{$motif_pwm}, "\n";
	#}






#subs--------------------------------------------------------------------------------------------
sub get_vdrbvs_from_file{
	my ($file, $hash) = @_;
	
	open (my $instream,  q{<}, $file) or die("Unable to open $file : $!");
	while(<$instream>){
		chomp;
		next if($_ =~ /^\#/);
		next if($_ eq '');
		
		#get coords
		my ($chr, $pos) = (split /\t/)[0,1];
		unless($chr =~ /^chr/){
			$chr = 'chr' . $chr;
		}
		my $coord = $chr . '-' . $pos;
		$$hash{$coord} = 1;
	}
	close $instream;	
	return;	
}


sub get_motif_lengths{
	my ($file, $hash) = @_;
	
	my $A = 1; my $C = 2; my $G = 3; my $T = 4;
	my $prev_name; my @info; my $temp;
	#slurp pwm file
	open (my $instream,  q{<}, $file) or die("Unable to open $file : $!");
		while(<$instream>){
			chomp $_;
			if(/^>/){
				$prev_name = (split/>|\s+/,$_)[1];
			}else{
				@info = split/\s+/,$_;
				if(not exists $$hash{$prev_name}){
					$$hash{$prev_name}->[0] = {(A=>$info[$A], T=>$info[$T], C=>$info[$C], G=>$info[$G])};
				}else{
					$temp = $$hash{$prev_name};
					$$hash{$prev_name}->[scalar(@$temp)] = {(A=>$info[$A], T=>$info[$T], C=>$info[$C], G=>$info[$G])};
				}
			}
		}
	close $instream;
	return;
}


sub get_pwm_id{
	my ($filename) = @_;
	my $identifier;
	my $motif_name;
	
	if($filename =~ /BVs_(.*)_(.*)_sites/){
		$motif_name = $1;
		$identifier = $2;
	}else{
		print STDERR "get_pwm_id(): ERROR - unable to recognise the input motif file name from: $filename. Aborting.\n";
		exit -1;
	}
	my $motif_id = $motif_name . '_' . $identifier;
	##heterodimers are saved by Jaspar as monomer::monomer
	##I replaced the :: with a '-' in the input file name because it's not recognised by the SGE submission	
	
	$motif_name =~ s/\-/\:\:/;
	#get the length of the motif analyzed in this iteration
	my $motif_id_postprocessed = $motif_name . '_' . $identifier;
	my $ref = $JASPAR_MOTIF{$motif_id_postprocessed};
	my $length = scalar(@$ref);	
	
	return($motif_id, $motif_id_postprocessed, $length);
}



sub write_ris_to_bed_file{
	my($in_file, $out_file, $pwm_length) = @_;
	my %hash;
	
	open (my $instream, q{<}, $in_file) or die("Unable to open $in_file : $!");
	while(<$instream>){
		chomp;
		next if($_ eq '');
		next if($_ =~ /^CHR/);
		
		my ($chr,$motif_start,$motif_end,$motif_strand,$score,$site) = (split /\t/)[0,4,5,8,9,10];
		#next if (!$chr);
		next if(  $MIN_SCORE && ($score < $MIN_SCORE) );
			
		my $pscanchip_interval_length = ($motif_end - $motif_start);
		if($pscanchip_interval_length <  $pwm_length){
			$motif_end += 1;
		}elsif($pscanchip_interval_length == $pwm_length){	
			;
		}else{
			print STDERR "ERROR: the pscanchip motif length is LARGER than the Jaspar length. Verify.\n";
			exit -1;	
		}
		my $bed_line = $chr . "\t" . $motif_start . "\t" . $motif_end . "\t" . $site . "\t" . $score;
		$hash{$bed_line} = 1;
	}
	close $instream;	
	
	open (my $outstream, q{>}, $out_file) or die("Unable to open $out_file : $!");
	foreach my $item (keys %hash){ 
		print $outstream $item, "\n"; 
	}
	close $outstream;
	return;
}


sub get_ris_intervals{
	my ($file, $pwm_length) = @_;
	my @array;
	
	open (my $instream,      q{<}, $file) or die("Unable to open $file : $!");
	while(<$instream>){
		chomp;
		next if($_ eq '');
		next if($_ =~ /^CHR/);
		
		my ($chr,$motif_start,$motif_end,$motif_strand,$score,$site) = (split /\t/)[0,4,5,8,9,10];
		#next if (!$chr);
		next if(  $MIN_SCORE && ($score < $MIN_SCORE) );
			
		my $pscanchip_interval_length = ($motif_end - $motif_start);
		if($pscanchip_interval_length <  $pwm_length){
			$motif_end += 1;
		}elsif($pscanchip_interval_length == $pwm_length){	
			;
		}else{
			print STDERR "ERROR: the pscanchip motif length is LARGER than the Jaspar length. Verify.\n";
			exit -1;	
		}
		my $bed_line = $chr . "\t" . $motif_start . "\t" . $motif_end . "\t" . $score;
		push(@array, $bed_line);
	}
	close $instream;
 	return @array;
}


# should return TRUE if the ris interval contains at least a VDR-BV; under otherwise
sub check_vdrbv_intersects_pwm_interval{
	my ($vdrbv_coords, @array) = @_;
	
	my ($vdrbv_chr,$vdrbv_pos) = split("-", $vdrbv_coords);
	#now search the array until you find an intersection
	foreach my $pwm_interval (@array){
		my ($pwm_chr, $pwm_start, $pwm_end, $score) = split("\t", $pwm_interval);
		if( ($pwm_chr eq $vdrbv_chr) && ($vdrbv_pos >= $pwm_start) && ($vdrbv_pos <= $pwm_end) ) {
			return $pwm_interval;
		}else{ 
			next;
		}	
	}
	return undef;
}
