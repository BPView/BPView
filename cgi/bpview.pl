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

use CGI qw(param);
use CGI::Fast;
use CGI::Carp qw(fatalsToBrowser);
use Log::Log4perl;


# for debugging only
use Data::Dumper;

# define default paths required to read config files
my ($lib_path, $cfg_path);
BEGIN {
  $lib_path = "../lib";		# path to BPView lib directory
  $cfg_path = "../etc";		# path to BPView etc directory
}


# load custom Perl modules
use lib "$lib_path";
use BPView::Config;
use BPView::Data;
use BPView::Web;


# open config files if not cached
my $conf = BPView::Config->new();

# open config file directory and push configs into hash
my $config = eval{ $conf->read_dir( dir => $cfg_path ) };
die "Reading configuration files failed.\nReason: $@" if $@;

# initialize Log4perl
my $logconf = "
    log4perl.category.BPView.Log		= WARN, Logfile
    log4perl.appender.Logfile			= Log::Log4perl::Appender::File
	log4perl.appender.Logfile.filename	= $config->{ 'logging' }{ 'logfile' }
    log4perl.appender.Logfile.layout	= Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern = %d %F: [%p] %m%n
";
Log::Log4perl::init( \$logconf );
my $log = Log::Log4perl::get_logger("BPView::Log");


# validate config
eval { $conf->validate( 'config' => $config ) };
$log->error_die($@) if $@;

my $views = eval { $conf->read_dir( dir	=> $cfg_path . "/views" ) };
$log->error_die($@) if $@;
# replaces possible arrays in views with hashes
$views = eval { $conf->process_views( 'config' => $views ) };
$log->error_die($@) if $@;
my $dashboards = eval { $conf->get_dashboards( 'config' => $views ) };
$log->error_die($@) if $@;



# loop for FastCGI
while ( my $q = new CGI::Fast ){

  # process URL
  if (defined param){
	
    # JSON Header
    print "Content-type: application/json charset=iso-8859-1\n\n";
    my $json = undef;
  
    if (defined param("dashboard")){
  	
      # get dashboard data
      my $dashboard = BPView::Data->new(
    	   views	=> $views->{ param("dashboard") }{ 'views' },
    	   provider	=> $config->{ 'provider' }{ 'source' },
    	   provdata	=> $config->{ $config->{ 'provider' }{ 'source' } },
         );	
      $json = eval { $dashboard->get_status() };
	  $log->error_die($@) if $@;
       
    }elsif (defined param("details")){
  	
  	  # get details for this business process
  	  my $details = BPView::Data->new(
  		  provider	=> 'bpaddon',
  		  provdata	=> $config->{ 'bpaddon' },
  		  bp		=> param("details"),
  	     );
  	  $json = eval { $details->get_details() };
	  $log->error_die($@) if $@;
  	
    }else{
  	
  	  $log->error_die("Unknown paramater!");
  	
    }
  
    print $json;
  
  }else{

    print "Content-type: text/html\n\n";

    # display web page
    my $page = BPView::Web->new(
 	  src_dir		=> $config->{ 'bpview' }{ 'src_dir' },
 	  data_dir	=> $config->{ 'bpview' }{ 'data_dir' },
 	  site_url	=> $config->{ 'bpview' }{ 'site_url' },
 	  template	=> $config->{ 'bpview' }{ 'template' },
    );
    #   $page->login();
    eval{ $page->display_page(
       page		=> "main",
       content	=> $dashboards,
       refresh	=> $config->{ 'refresh' }{ 'interval' },
    ) };
    $log->error_die($@) if $@;

  }

}

exit 0;
