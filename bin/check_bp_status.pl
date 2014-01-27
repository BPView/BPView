#!/usr/bin/perl -w
# nagios: -epn
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
use Getopt::Long;

# for debugging only
#use Data::Dumper;

# define default paths required to read config files
my ($lib_path, $cfg_path);
BEGIN {
  $lib_path = "/usr/lib64/perl5/vendor_perl";   # path to BPView lib directory
  $cfg_path = "/etc/bpview";                    # path to BPView etc directory
}

# load custom Perl modules
use lib "$lib_path";
use BPView::Config;
use BPView::Data;
use BPView::BP;

# Configuration
# all values can be overwritten via command line options
my $timeout = 10;			# default timeout

# Variables
my $prog		= "check_bp_status";
my $version		= "1.0.";
my $projecturl  = "https://github.com/ovido/BPView";
my $bp_dir		= $cfg_path . "/bp-config";

my $o_verbose	= undef;			# verbosity
my $o_help		= undef;			# help
my $o_version	= undef;			# check_bp_status version
my $o_bp		= undef;			# business process name
my $o_timeout	= undef;			# timeout

my %status	= ( ok => "OK", warning => "WARNING", critical => "CRITICAL", unknown => "UNKNOWN");
my %ERRORS	= ( "OK" => 0, "WARNING" => 1, "CRITICAL" => 2, "UNKNOWN" => 3);


#***************************************************#
#  Function: parse_options                          #
#---------------------------------------------------#
#  parse command line parameters                    #
#                                                   #
#***************************************************#
sub parse_options(){
  Getopt::Long::Configure ("bundling");
  GetOptions(
	'v+'	=> \$o_verbose,	'verbose+'	=> \$o_verbose,
	'h'		=> \$o_help,	'help'		=> \$o_help,
	'b:s'	=> \$o_bp,		'bp:s'		=> \$o_bp,
	'V'		=> \$o_version,	'version'	=> \$o_version,
	't:i'	=> \$o_timeout,	'timeout:i'	=> \$o_timeout
  );

  # process options
  print_help()		if defined $o_help;
  print_version()	if defined $o_version;
  
  if (! defined( $o_bp )){
    print "Business process name is missing.\n";
    print_usage();
    exit $ERRORS{$status{'unknown'}};
  }
  
  $timeout   = $o_timeout	if defined $o_timeout;
  $o_verbose = 0	if (! defined $o_verbose);
  $o_verbose = 0	if $o_verbose <= 0;
  $o_verbose = 3	if $o_verbose >= 3; 
  
}


#***************************************************#
#  Function: print_usage                            #
#---------------------------------------------------#
#  print usage information                          #
#                                                   #
#***************************************************#
sub print_usage(){
  print "Usage: $0 [-v] -b <business_process> [-t <timeout>] [-V] \n";
}


#***************************************************#
#  Function: print_help                             #
#---------------------------------------------------#
#  print help text                                  #
#                                                   #
#***************************************************#
sub print_help(){
  print "\nBusiness process checks for Icinga/Nagios version $version\n";
  print "             (c) 2013 ovido gmbh <sales\@ovido.at>\n\n";
  print_usage();
  print <<EOT;

Options:
 -h, --help
    Print detailed help screen
 -V, --version
    Print version information
 -b, --bp
    Short name of the business process to check
 -t, --timeout=INTEGER
    Seconds before connection times out (default: $timeout)
 -v, --verbose
    Show details for command-line debugging
    (Icinga/Nagios may truncate output)

Send email to sales\@ovido.at if you have questions regarding use
of this software. To submit patches of suggest improvements, send
email to sales\@ovido.at
EOT

exit $ERRORS{$status{'unknown'}};
}


#***************************************************#
#  Function: print_version                          #
#---------------------------------------------------#
#  Display version of plugin and exit.              #
#                                                   #
#***************************************************#

sub print_version{
  print "$prog $version\n";
  exit $ERRORS{$status{'unknown'}};
}


#***************************************************#
#  Function: main                                   #
#---------------------------------------------------#
#  The main program starts here.                    #
#                                                   #
#***************************************************#

# parse command line options
parse_options();

# open config file
my $conf = BPView::Config->new();
# open config file directory and push configs into hash
my $config = eval{ $conf->read_dir( dir => $cfg_path ) };
if ($@) {
  print "Reading configuration files failed.\nReason: $@";
  exit $ERRORS{$status{'unknown'}}; 
}

# TODO: minimal validation required (e.g. src dir isn't required for plugin)
# validate config
#eval { $conf->validate( 'config' => $config ) };
#if ($@) {
#  print "Validating configuration files failed.\nReason: $@";
#  exit $ERRORS{$status{'unknown'}}; 
#}

# Read status data from database
my $data = BPView::Data->new(
			provider	=> $config->{ 'provider' }{ 'source' },
			provdata	=> $config->{ $config->{ 'provider' }{ 'source' } },
         );
my $status = eval { $data->get_bpstatus() };
if ($@) {
  print "Faild to read status data.\nReason: $@";
  exit $ERRORS{$status{'unknown'}}; 
}

# Open business process config file
# open config file directory and push configs into hash
my $bpconfig = eval{ $conf->read_config( file => $bp_dir . "/" . $o_bp . ".yml" ) };
if ($@) {
  print "Reading configuration files failed.\nReason: $@";
  exit $ERRORS{$status{'unknown'}}; 
}

# process BPs
my $bp = BPView::BP->new(
		bps			=> $status,
		bpconfig	=> $bpconfig,
		);
my $result = eval { $bp->get_bpstatus() };
if ($@) {
  print "Processing BPs failed.\nReason: $@";
  exit $ERRORS{$status{'unknown'}}; 
}

print "Business process " . $o_bp . " is " . uc( $result ) . "\n";
exit $ERRORS{$status{$result}};
