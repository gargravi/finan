#!/usr/bin/perl

#Prereq
#--------------------------------------------------
#ActiveState Perl
#ppm install Text-CSV
#ppm install Finance-Math-IRR

#Input
#--------------------------------------------------
# Scripts calulates xirr on input csv Format WITHOUT HEADER ("Scheme,Quantity,InvestDate,InvetAmout,CurrentAmount") 
# ./invest_xirr.pl ./input.csv
# output --> input.csv_report_<today's Date>.csv


use strict;
use warnings;
use Class::Struct;
use Text::CSV;
use Finance::Math::IRR;
use Data::Dumper qw(Dumper);

use POSIX qw(strftime);
use my_defs;

    local $Finance::Math::IRR::DEBUG = 1;
	
# Set mapping of the input csv as below (indexes starts from zero)
my %in_csv_mapping = ('scheme', 0,	'quantity', 1, 'inv_date', 2, 'principal', 3, 'curr_amount' , 4 );
my $today_date = strftime "%Y-%m-%d", localtime;
my $in_file = $ARGV[0];

my $ret_info_glbl = new returns_info;
$ret_info_glbl->scheme( "Entire" );
$ret_info_glbl->total_qantity( 0 );
$ret_info_glbl->total_principal( 0 );
$ret_info_glbl->total_curr_amount( 0 );
$ret_info_glbl->cacluated_xirr(0 );
$ret_info_glbl->installments(0 );

my %portfolio;

sub extract
{
	my @inv_info_lst;
	
	# Read CSV
	my $csv = Text::CSV->new({ sep_char => ',' });
	 
	my $file = shift or die "Need to get CSV file on the command line\n";
	my $sum = 0;
	open(my $data, '<', $file) or die "Could not open '$file' $!\n";
	while (my $line = <$data>) 
	{
	  chomp $line; 	
	  if ($csv->parse($line)) {
		  my @fields = $csv->fields();
		  my $inv_info = new invest_info;
		  $inv_info->scheme(  $fields[ $in_csv_mapping{'scheme'} ] ); 
		  $inv_info->quantity(  $fields[ $in_csv_mapping{'quantity'} ] );
		  $inv_info->inv_date(  $fields[ $in_csv_mapping{'inv_date'} ] );
		  $inv_info->principal(  $fields[ $in_csv_mapping{'principal'} ] );
		  $inv_info->curr_amount(  $fields[ $in_csv_mapping{'curr_amount'} ] );
		  push(@inv_info_lst, $inv_info ); 
	  } else {
		  warn "Line could not be parsed: $line\n";
	  }
	} 
	return @inv_info_lst;
}

 
sub transform
{
	#my $today_date = strftime "%Y-%m-%d", localtime;
	my @inv_info_lst = @{$_[0]}; 
	 
	my %schme_wise_all;
	foreach my $inv_info (@inv_info_lst) 
	{	
		if( exists( $schme_wise_all{ $inv_info->scheme() } ) )
		{
			my $arrRev = $schme_wise_all{ $inv_info->scheme() };
			push( @$arrRev , $inv_info );
		}
		else{
			my @inv_info_lst = ($inv_info);
			$schme_wise_all{ $inv_info->scheme() } = \@inv_info_lst ;
		}
	}

	my @returns_lst;
	while( my($kyy, $vaa) = each %schme_wise_all )
	{ 
		#print "\n --- Scheme : $kyy -----", scalar @$vaa ;
		my $ret_info = new returns_info;
		$ret_info->scheme( $kyy );
		$ret_info->total_qantity( 0 );
		$ret_info->total_principal( 0 );
		$ret_info->total_curr_amount( 0 );
		$ret_info->cacluated_xirr(0 );
		$ret_info->installments(0 );
		my %cashflow;
		foreach my $inv_inf ( @$vaa ) 
		{
			$ret_info->total_qantity( $ret_info->total_qantity + $inv_inf->quantity );
			$ret_info->total_principal( $ret_info->total_principal + $inv_inf->principal );
			$ret_info->total_curr_amount( $ret_info->total_curr_amount + $inv_inf->curr_amount );
			$ret_info->installments( $ret_info->installments + 1 );
			my @dr = split(/-/, $inv_inf->inv_date, 3);
			my $nw_dt = $dr[2] . "-". $dr[1] . "-" . $dr[0]; 
			if( exists( $cashflow{$nw_dt} ) ) {
				$cashflow{ $nw_dt } = ( $cashflow{ $nw_dt } + (-1 * $inv_inf->principal) );
			} else{
				$cashflow{ $nw_dt } = (-1 * $inv_inf->principal);
			}
						
			$ret_info_glbl->total_principal ($inv_inf->principal + $ret_info_glbl->total_principal );
			$ret_info_glbl->total_curr_amount ($inv_inf->curr_amount + $ret_info_glbl->total_curr_amount );
			if( exists( $portfolio{$nw_dt} ) ) {
				$portfolio{ $nw_dt } = ( $portfolio{ $nw_dt } + (-1 * $inv_inf->principal) );
			} else{
				$portfolio{ $nw_dt } = (-1 * $inv_inf->principal);
			}	
		}
		$cashflow{ $today_date } = $ret_info->total_curr_amount; 
		#print Dumper \%cashflow;
		
		my %cashflow_srt;
		foreach my $dtKey (sort keys %cashflow) {
			my $valx =  $cashflow{$dtKey};
			my $kyx =  $dtKey;
			$cashflow_srt{$kyx} = $valx;
			#print "\n [$kyx -> $cashflow_srt{$kyx} ]"
		}
		
		#print Dumper \%cashflow_srt;
		my $irr = xirr(precision => 0.001, %cashflow_srt);
		#my $irr = xirr(precision => 0.001, %cashflow);
		$ret_info->cacluated_xirr( $irr );

		push( @returns_lst, $ret_info);
		#print "\nxirr : $irr\n";
	}
	
	$portfolio{ $today_date } = $ret_info_glbl->total_curr_amount;
	my $irrPrt = xirr(precision => 0.001, %portfolio);
	$ret_info_glbl->cacluated_xirr( $irrPrt );

	#push( @returns_lst, $ret_info_glbl);
	
	return @returns_lst;
}
 
sub load {
	my $returns_lst = shift;
	
	my $filename = $in_file . '_report' . $today_date . '_.csv';
	open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
	print $fh "Scheme,Installments,Quantity,InvetAmout,CurrentValue,XIRR,Weightage\n";
	
	my $value_now = 0;
	foreach my $ret_infa ( @$returns_lst ) 
	{
		$value_now += $ret_infa->total_curr_amount;
	}
	
	push( @$returns_lst, $ret_info_glbl);
	foreach my $ret_inf ( @$returns_lst ) 
	{
		my $prStr = $ret_inf->scheme .
			"," . $ret_inf->installments .
			"," . $ret_inf->total_qantity .
			"," . $ret_inf->total_principal .
			"," . $ret_inf->total_curr_amount .
			"," . $ret_inf->cacluated_xirr .
			"," . ($ret_inf->total_curr_amount / $value_now);
			print $fh "$prStr\n"; 
		print $prStr , "\n";
	}
	close $fh;
	print "done\n";
	
}

my @inv_info_lst =  extract( $in_file );
my @returns_lst = transform( \@inv_info_lst ); 
load( \@returns_lst );
