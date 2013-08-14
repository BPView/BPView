#!/usr/bin/perl -w
#
# COPYRIGHT:
#
# This software is Copyright (c) 2013 by ovido
#                             <sales@ovido.at>
#
# This file is part of Business Process View (BPView).
#
# (Except where explicitly superseded by other copyright notices)
# BPView is free software: you can redistribute it and/or modify it 
# under the terms of the GNU General Public License as published by 
# the Free Software Foundation, either version 3 of the License, or 
# any later version.
#
# BPView is distributed in the hope that it will be useful, but WITHOUT 
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License 
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with BPView.  
# If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use YAML::Syck;
use File::Spec;
use POSIX qw/strftime/;

# for debugging only
use Data::Dumper;

# define default paths required to read config files
my ($lib_path, $cfg_path, $dir);
BEGIN {
  $lib_path = "../lib";		# path to BPView lib directory
  $cfg_path = "../etc";		# path to BPView etc directory
  $dir		= $cfg_path . "/bp-config";
}

use lib "$lib_path";
use BPView::Config;
use BPView::BPWriter;

# open config files if not cached
my $conf = BPView::Config->new();

# open config file directory and push configs into hash
my $config = eval{ $conf->read_dir( dir => $cfg_path ) };
die "Reading configuration files failed.\nReason: $@" if $@;

# validate config
exit 1 unless ( $conf->validate( 'config' => $config ) == 0);


sub error_msg {
	my $message = shift(@_);
	print "$message\n";
}


# load custom Perl modules
use lib "$lib_path";
##use BPView::Config;






# open config file directory and push configs into hash
my $yaml = $conf->read_dir( dir => $dir );

exit 1 unless ( $conf->validate_bpconfig( 'config' => $yaml ) == 0);





my $time = strftime('%A, %d-%b-%Y %H:%M',localtime); ## outputs 17-Dec-2008 10:08

my $output = "#######################################################################\n" .
			 "#   Automatically generated config file for Business Process Addon \n" .
			 "#   Generated with: BPView - http://github.com/ovido/BPView    \n" .
			 "#   Generated on: $time    \n" .
			 "#######################################################################\n\n\n";


foreach my $bp_host (keys %{ $yaml }) {

	my $type_var;
	
	if ($yaml->{$bp_host}{'BP'}{'TYPE'} eq "or") {
		$type_var = "|";
	}
	elsif ($yaml->{$bp_host}{'BP'}{'TYPE'} eq "and") {
		$type_var = "&";
	}
	elsif ($yaml->{$bp_host}{'BP'}{'TYPE'} eq "min") {
		$type_var = "+";
	}
	else {
	#	error_msg("You have an error at the TYPE declaration on file: \"$file\". You need to fix it.");
		exit;
	}
	
	$output .= "# BP-Definition:  ". $yaml->{$bp_host}{'BP'}{'NAME'} ."\n";
	$output .= "# BP-Description: ". $yaml->{$bp_host}{'BP'}{'DESC'} ."\n";
	$output .= "#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n";




	my $bp_text = "$yaml->{$bp_host}{'BP'}{'FILE'} = ";
	if ($yaml->{$bp_host}{'BP'}{'TYPE'} eq "min") {
		$bp_text .= "$yaml->{$bp_host}{'BP'}{'MIND'} of: ";
	}

#production-mail-zarafa = ovido-tyr.dmz.ovido.at;SMTP Check & ovido-tyr.dmz.ovido.at;Zarafa Idle Threads & ovido-tyr.dmz.ovido.at;Zarafa Queue Age
#display 0;production-mail-zarafa;Zarafa



	foreach my $key0 (keys %{ $yaml->{$bp_host}{'HOSTS'} }) {
		foreach my $key1 (keys %{ $yaml->{$bp_host}{'HOSTS'}->{ $key0 } }) {
			if ($key0 eq "BPROC") {
				$bp_text .= "$key1;$key1 $type_var ";
			}
			else {
				$bp_text .= "$key0;$key1 $type_var ";
			}
		}
	}
	$bp_text = substr($bp_text,0,-3," $type_var ");
	$output .= "$bp_text\n";
	$output .= "display $yaml->{$bp_host}{'BP'}{'DISP'};$yaml->{$bp_host}{'BP'}{'FILE'};$yaml->{$bp_host}{'BP'}{'NAME'}\n";
	$output .= "###########################################################################\n\n\n\n";


}

print $output;

exit 0;