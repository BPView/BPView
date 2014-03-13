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
use JSON::PP;


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
my $reload_log = "/var/log/bpview/reload.log";
my $logconf = "
    log4perl.category.BPView.Log		= INFO, BPViewLog
    log4perl.category.BPViewReload.Log	= INFO, BPViewReloadLog
    log4perl.appender.BPViewLog				= Log::Log4perl::Appender::File
	log4perl.appender.BPViewLog.filename	= $config->{ 'logging' }{ 'logfile' }
    log4perl.appender.BPViewLog.layout		= Log::Log4perl::Layout::PatternLayout
    log4perl.appender.BPViewLog.layout.ConversionPattern = %d %F: [%p] %m%n
    log4perl.appender.BPViewReloadLog			= Log::Log4perl::Appender::File
	log4perl.appender.BPViewReloadLog.filename	= $reload_log
    log4perl.appender.BPViewReloadLog.layout	= Log::Log4perl::Layout::PatternLayout
    log4perl.appender.BPViewReloadLog.layout.ConversionPattern = %d %F: [%p] %m%n
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
# get dashboards
my $dashboards = eval { $conf->get_dashboards( 'config' => $views ) };
$log->error_die($@) if $@;
# get css files
my $css_files = eval { $conf->get_css( 'config' => $config ) };
$log->error_die($@) if $@;



# loop for FastCGI
while ( my $q = new CGI::Fast ){

  my $uri_dashb  = "0";
  my $uri_filter = "";
  
  if (defined param("dashboard")){
  	$uri_dashb = param("dashboard");
  }
  
  if (defined param("dash")){
  	$uri_dashb = param("dash");
  }
  
  if (defined param("reload")){
    print "Content-type: application/json; charset=utf-8\n\n";
    use BPView::Operations;
	my $operations = BPView::Operations->new(
    	   config	=> $config,
    	   cfg_path	=> $cfg_path,
         );

    my $return = undef;

    if (param("reload") eq "true"){
	  $return = eval { $operations->generate_config() };
	  $log->info($@) if $@;
    }elsif (param("reload") eq "status"){
      $return = $operations->_status_script();
    }
    
  	my $json = JSON::PP->new->pretty->allow_nonref;
    $json->utf8('true');
    if (ref($return) ne "HASH"){
      # config generation failed
      $return = undef;
      $return->{ 'status' } = 0;
      $return->{ 'message' } = "Another instance is already running!";
    }

    print $json->encode($return);

  # process URL
  }elsif ((defined param) && defined (!param("reload")) && defined(!param("dash"))) {

    # JSON Header
    my $json = undef;

    if (defined param("dashboard") && param("json")){
      print "Content-type: application/json; charset=utf-8\n\n";
    
      # use filters to display only certain states or hosts
      my $filter = {};
      # we expect the GET information in the following form:
      # bpview.pl?dashboard=db&filter=state+ok
      # bpview.pl?dashboard=db&filter=name+loadbalancer
      
      if (defined param("filter")){
      	$log->error_die("Unsupported parameter options: " . param("filter")) unless ( param("filter") =~ /^state/ || param("filter") =~  /^name/);
      	my @filterval = split / /, param("filter");
      	
      	my $filtername = undef;
        for (my $i=0;$i<=$#filterval; $i++){
                      
          # get name for filter
          if ($filterval[$i] eq "state"){
            $filtername = $filterval[$i];
            next;
          }elsif ($filterval[$i] eq "name"){
            $filtername = $filterval[$i];
            next;
          }
                      
          # state filter
          if ( ( $filtername eq "state" ) && ( $filterval[$i] ne "ok" && $filterval[$i] ne "warning" && $filterval[$i] ne "critical" && $filterval[$i] ne "unknown" ) ){
            $log->error_die("Invalid filter option: " . $filterval[$i]);
          }elsif ($filtername eq "state"){
            push @{ $filter->{ $filtername } }, $filterval[$i];        
          }
              
              
          # hostname filter
          if ( ( $filtername eq "name" ) && ( $filterval[$i] !~ /^[a-zA-Z0-9_.-]*$/ ) ){
            $log->error_die("Invalid filter characters option: " . $filterval[$i]);
          }elsif ($filtername eq "name"){
            push @{ $filter->{ $filtername } }, $filterval[$i];
          }
              
        }
      	
      }
      
  	
      # get dashboard data
      my $dashboard = BPView::Data->new(
  		   config	=> $config,
    	   views	=> $views->{ param("dashboard") }{ 'views' },
    	   provider	=> $config->{ 'bpview' }{ 'datasource' },
    	   provdata	=> $config->{ 'bpview'}{ $config->{ 'bpview' }{ 'datasource' } },
    	   bps		=> $bps,
    	   filter	=> $filter,
         );
      $json = eval { $dashboard->get_status() };
#	  $log->error_die($@) if $@;
      if ($@){
      	my $error_message->{ 'error' } = $@;
      	$log->error($error_message->{ 'error' });
      	
      	# make output more pretty for users
        $error_message->{ 'error' } =~ s/\n/<br>/g;
        $error_message->{ 'error' } =~ s/:  at.*//;
        
      	$json = JSON::PP->new->pretty;
        $json->utf8('true');
        $json = $json->encode($error_message);
      }
       
    }elsif (defined param("details")){
      print "Content-type: application/json; charset=utf-8\n\n";
  	
  	  # use filters to display only certain states or hosts
      my $filter = undef;
      # we expect the GET information in the following form:
      # bpview.pl?dashboard=db&filter=state+ok
      # bpview.pl?dashboard=db&filter=name+loadbalancer
      
       if (defined param("filter")){
      	$log->error_die("Unsupported parameter options: " . param("filter")) unless ( param("filter") =~ /^state/ || param("filter") =~  /^name/);
      	my @filterval = split / /, param("filter");
      	
      	my $filtername = undef;
        for (my $i=0;$i<=$#filterval; $i++){
                      
          # get name for filter
          if ($filterval[$i] eq "state"){
             $filtername = $filterval[$i];
             next;
          }elsif ($filterval[$i] eq "name"){
             $filtername = $filterval[$i];
             next;
          }
                    
          # state filter
          if ( ( $filtername eq "state" ) && ( $filterval[$i] ne "ok" && $filterval[$i] ne "warning" && $filterval[$i] ne "critical" && $filterval[$i] ne "unknown" ) ){
             $log->error_die("Invalid filter option: " . $filterval[$i]);
          }elsif ($filtername eq "state"){
            push @{ $filter->{ $filtername } }, $filterval[$i];        
          }
              
              
          # hostname filter
          if ( ( $filtername eq "name" ) && ( $filterval[$i] !~ /^[a-zA-Z0-9_.-]*$/ ) ){
            $log->error_die("Invalid filter characters option: " . $filterval[$i]);
          }elsif ($filtername eq "name"){
            push @{ $filter->{ $filtername } }, $filterval[$i];
          }
              
        }
      	
      }
      
  	  # get details for this business process
  	  my $details = BPView::Data->new(
  		  config	=> $config,
  		  bp		=> param("details"),
  		  provider	=> $config->{ 'provider' }{ 'source' },
    	  provdata	=> $config->{ $config->{ 'provider' }{ 'source' } },
		  bps		=> $bps,
   	      filter	=> $filter,
  	     );
  	  $json = eval { $details->get_details() };
#	  $log->error_die($@) if $@;
      if ($@){
      	my $error_message->{ 'error' } = $@;
      	$log->error($error_message->{ 'error' });
      	
      	# make output more pretty for users
        $error_message->{ 'error' } =~ s/\n/<br>/g;
        $error_message->{ 'error' } =~ s/:  at.*//;
      	
      	$json = JSON::PP->new->pretty;
        $json->utf8('true');
        $json = $json->encode($error_message);
      }
  	
    }elsif (defined param("css") || (defined param("dash"))){
  	
  	  # override default template using GET variable 
  	  print "Content-type: text/html\n\n";
  	  $log->error_die("Invalid character in template variable: " . param("template")) unless param("template") =~ /^[a-zA-Z0-9_-]*$/;
  	  
  	  my $css = "bpview";
  	  if (defined param("css")){
  	  	$css = param("css");
  	  }
  	  
  	  if (defined param("filter")){
  	  	$uri_filter = param("filter");
  	  	$uri_filter =~ s/%2B/+/g;
  	  	$uri_filter =~ s/ /+/g;
  	  }

      # display web page
      my $page = BPView::Web->new(
 	    src_dir		=> $config->{ 'bpview' }{ 'src_dir' },
 	    data_dir	=> $config->{ 'bpview' }{ 'data_dir' },
 	    site_url	=> $config->{ 'bpview' }{ 'site_url' },
 	    template	=> $config->{ 'bpview' }{ 'template' },
 	    css			=> $css,
 	    site_name 	=> $config->{ 'bpview' }{ 'site_name' },
      );

      #   $page->login();
      eval{ $page->display_page(
         page		=> "main",
         content	=> $dashboards,
         refresh	=> $config->{ 'refresh' }{ 'interval' },
#         reloadit	=> $reloadit,
         uri_dashb	=> $uri_dashb,
         uri_filter	=> $uri_filter,
         styles		=> $css_files,
      ) };
      $log->error_die($@) if $@;

    
    }else{
		my $query=new CGI;
		print $query->redirect("$ENV{'HTTP_HOST'}$config->{ 'bpview' }{ 'site_url' }");
#  	  $log->error_die("Unknown parameter!");
  	
    }
  
    print $json unless defined param("template");
  	
  }else{
  	
  	# use default template specified in bpview.yml
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
       page			=> "main",
       content		=> $dashboards,
       refresh		=> $config->{ 'refresh' }{ 'interval' },
#       reloadit		=> $reloadit,
       uri_dashb	=> $uri_dashb,
       styles		=> $css_files,
    ) };
    $log->error_die($@) if $@;

  }

}

exit 0;
