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
  $lib_path = "/usr/lib64/perl5/vendor_perl";   # path to BPView lib directory
  $cfg_path = "/etc/bpview";                    # path to BPView etc directory
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
    log4perl.category.BPView.Log		= INFO, Logfile
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

# open config file directory and push configs into hash
my $bps = eval {$conf->read_dir( dir => $cfg_path . "/bp-config" )};
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

  my $reloadit  = "no";
  my $reloadnow = "no";

  if (defined param("reloadit")) {
  	$reloadit = "yes" if (param("reloadit") eq "yes");
  }
  if (defined param("reloadnow")) {
    $reloadnow = "yes" if (param("reloadnow") eq "yes");
  }
  if ($reloadnow eq "yes" and $reloadit eq "yes") {
	print "Content-type: text/html\n\n";
    use BPView::Operations;
	my $operations = BPView::Operations->new(
    	   config	=> $config,
    	   cfg_path	=> $cfg_path,
         );
    my $round = "0";
    $round = param("round") if (defined param("round"));
	if ($round eq "1") {
		sleep 3;
		eval { $operations->import_cmdb() };
		eval { $operations->write_cfgs() };
		eval { $operations->reload() };
		$log->info("\n>>>>>>\n>>>>>> Restarting the BPView Instance ...\n>>>>>>\n>>>>>>\n");
	}

    my $page = BPView::Web->new(
 	  src_dir	=> $config->{ 'bpview' }{ 'src_dir' },
 	  data_dir	=> $config->{ 'bpview' }{ 'data_dir' },
 	  site_url	=> $config->{ 'bpview' }{ 'site_url' },
 	  template	=> $config->{ 'bpview' }{ 'template' },
 	  site_name => $config->{ 'bpview' }{ 'site_name' },
    );
	#   $page->login();
	eval{ $page->display_page(
		page		=> "iframe",
		round		=> $round,
		reloadit	=> $reloadit,
	)};
	$log->error_die($@) if $@;
	if ($round eq "1") {
		exit;
	}
	else {
		last;
	}
  }

  # process URL
  if ((defined param) && ($reloadit eq "no")) {

    # JSON Header
    my $json = undef;

    if (defined param("dashboard")){
      print "Content-type: application/json; charset=utf-8\n\n";
    
      # use filters to display only certain states or hosts
      my $filter = undef;
      # we expect the GET information in the following form:
      # bpview.pl?dashboard=db&filter=state+ok
      # bpview.pl?dashboard=db&filter=name+loadbalancer
      
      if (defined param("filter")){
      	$log->error_die("Unsupported parameter options: " . param("filter")) unless param("filter") =~ /^state/;
      	my @filterval = split / /, param("filter");
      	# check for invalid options
      	
      	if ($filterval[1] ne "ok" && $filterval[1] ne "warning" && $filterval[1] ne "critical" && $filterval[1] ne "unknown"){
      	  $log->error_die("Invalid filter option: " . $filterval[1]);
      	}else{
      	  $filter = { $filterval[0] => $filterval[1] };	
      	}
      	
      }
  	
      # get dashboard data
      my $dashboard = BPView::Data->new(
    	   views	=> $views->{ param("dashboard") }{ 'views' },
    	   provider	=> $config->{ 'provider' }{ 'source' },
    	   provdata	=> $config->{ $config->{ 'provider' }{ 'source' } },
    	   bps		=> $bps,
    	   filter	=> $filter,
         );
      $json = eval { $dashboard->get_status() };
	  $log->error_die($@) if $@;
       
    }elsif (defined param("details")){
      print "Content-type: application/json; charset=utf-8\n\n";
  	
  	  # use filters to display only certain states or hosts
      my $filter = undef;
      # we expect the GET information in the following form:
      # bpview.pl?dashboard=db&filter=state+ok
      # bpview.pl?dashboard=db&filter=name+loadbalancer
      
      if (defined param("filter")){
      	$log->error_die("Unsupported parameter options: " . param("filter")) unless param("filter") =~ /^state/;
      	my @filterval = split / /, param("filter");
      	# check for invalid options
      	
      	if ($filterval[1] ne "ok" && $filterval[1] ne "warning" && $filterval[1] ne "critical" && $filterval[1] ne "unknown"){
      	  $log->error_die("Invalid filter option: " . $filterval[1]);
      	}else{
      	  $filter = { $filterval[0] => $filterval[1] };	
      	}
      	
      }
      
  	  # get details for this business process
  	  my $details = BPView::Data->new(
  		  config	=> $config,
  		  bp		=> param("details"),
   	      filter	=> $filter,
  	     );
  	  $json = eval { $details->get_details() };
	  $log->error_die($@) if $@;
  	
    }else{
		my $query=new CGI;
		print $query->redirect("$ENV{'HTTP_HOST'}$config->{ 'bpview' }{ 'site_url' }");
#  	  $log->error_die("Unknown parameter!");
  	
    }
  
    print $json;
  
  }else{
    print "Content-type: text/html\n\n";

    # display web page
    my $page = BPView::Web->new(
 	  src_dir	=> $config->{ 'bpview' }{ 'src_dir' },
 	  data_dir	=> $config->{ 'bpview' }{ 'data_dir' },
 	  site_url	=> $config->{ 'bpview' }{ 'site_url' },
 	  template	=> $config->{ 'bpview' }{ 'template' },
 	  site_name => $config->{ 'bpview' }{ 'site_name' },
    );

    #   $page->login();
    eval{ $page->display_page(
       page		=> "main",
       content	=> $dashboards,
       refresh	=> $config->{ 'refresh' }{ 'interval' },
       reloadit	=> $reloadit,
    ) };
    $log->error_die($@) if $@;

  }

}

exit 0;
