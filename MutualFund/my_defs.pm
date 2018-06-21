#!/usr/bin/perl
package my_defs;
use strict;
use warnings;

use Class::Struct;

struct invest_info => {
	scheme		=> '$',
	quantity	=> '$',
	inv_date	=> '$',
	principal	=> '$',
	curr_amount	=> '$'
};
 

struct returns_info => {
	scheme				=> '$',
	installments		=> '$',
	total_qantity		=> '$',
	total_principal		=> '$',
	total_curr_amount	=> '$',
	cacluated_xirr		=> '$'
}; 

1;