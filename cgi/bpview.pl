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
my ($lib_path, $cfg_path, $cfg_file, $log_path, $reload_log);


#----------------------------------------------------------------
#
# Configuration
#

BEGIN {
  $lib_path = "/usr/lib64/perl5/vendor_perl";   # path to BPView lib directory
  $cfg_path = "/etc/bpview";                    # path to BPView etc directory
  $cfg_file = "bpview.yml";                     # BPView config file
  $log_path = "/var/log/bpview/";               # log file path
  $reload_log = $log_path . "reload.log";   	# path to BPView reload log file (default: /var/log/bpview/reload.log)
}

#
# End of configuration block - don't change anything below
# this line!
#
#----------------------------------------------------------------


# load custom Perl modules
use lib "$lib_path";
use BPView::Config;
use BPView::Web;


# open config files if not cached
my $conf = BPView::Config->new();

# open config file directory and push configs into hash
my $config = eval{ $conf->read_config( file => $cfg_path . "/" . $cfg_file ) };
die "Reading configuration files failed.\nReason: $@" if $@;

# initialize Log4perl
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
eval { $conf->validate_bpview( 'config' => $config ) };
$log->error_die($@) if $@;

# open config file directory and push configs into hash
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
  

#----------------------------------------------------------------
# Reload web application


  if (defined param("reload")){
    print "Content-type: application/json; charset=utf-8\n\n";
    use BPView::Operations;
	my $operations = BPView::Operations->new(
    	   config		=> $config,
    	   cfg_path		=> $cfg_path,
    	   reload_log	=> $reload_log,
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

    print $json->encode($return);


#----------------------------------------------------------------
# Process URL


  }elsif ((defined param) && defined (!param("reload")) && defined(!param("dash"))) {

    # JSON Header
    my $json = undef;


    #----------------------------------------------------------------
    # Get JSON status for given dashboard    
    
    if (defined param("dashboard") && param("json")){
      print "Content-type: application/json; charset=utf-8\n\n";
    
      # use filters to display only certain states or hosts
      my $filter = {};
      # we expect the GET information in the following form:
      # bpview.pl?dashboard=db&filter=state+ok
      # bpview.pl?dashboard=db&filter=name+loadbalancer
      
      if (defined param("filter")){
      	$filter = _get_filter( param("filter") );
      }
       
      my $data = {
      	'GET'		=> 'businessprocesses',
      	'FILTER'	=> { 'dashboard'	=> param('dashboard'),
      						'state'				=> $filter->{ 'state' },
      						'name'				=> $filter->{ 'name' }, 
        },
      };
      
      $json = _connect_api( $data );
      
      print STDERR Dumper $json;


    #----------------------------------------------------------------
    # Get details for given business process in JSON format
    
    }elsif (defined param("details")){
      print "Content-type: application/json; charset=utf-8\n\n";
  	
  	  # use filters to display only certain states or hosts
      my $filter = undef;
      # we expect the GET information in the following form:
      # bpview.pl?dashboard=db&filter=state+ok
      # bpview.pl?dashboard=db&filter=name+loadbalancer
      
      if (defined param("filter")){
      	$filter = _get_filter( param("filter") );
      }
      
      my $data = {
      	'GET'		=> 'services',
      	'FILTER'	=> { 	'businessprocess'	=> param('details'),
      						'state'				=> $filter->{ 'state' },
      						'name'				=> $filter->{ 'name' }, 
      	},
      };
      
      $json = _connect_api( $data );
      
  	
  	#----------------------------------------------------------------
    # Display requested web page
    
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
         uri_dashb	=> $uri_dashb,
         uri_filter	=> $uri_filter,
         styles		=> $css_files,
      ) };
      $log->error_die($@) if $@;

    
    #----------------------------------------------------------------
    # Redirect to main page
    
    }else{
		my $query=new CGI;
		print $query->redirect("$ENV{'HTTP_HOST'}$config->{ 'bpview' }{ 'site_url' }");
#  	  $log->error_die("Unknown parameter!");
  	
    }
  
    print $json unless defined param("template");


#----------------------------------------------------------------
# Display default web page

  	
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
       uri_dashb	=> $uri_dashb,
       styles		=> $css_files,
    ) };
    $log->error_die($@) if $@;

  }

}


#----------------------------------------------------------------

# internal methods
##################

# connect to bpviewd socket
sub _connect_api {

  use IO::Socket::INET;
  
  my $query = shift or die "Missing query for API connect!";
  
  # prepare JSON data
  my $json = JSON::PP->new->pretty;
  $json->utf8('true');
  $json = $json->encode($query);
  
  # auto-flush on socket
  $| = 1;
  
  # create a connection socket
  my $socket = new IO::Socket::INET (
  	PeerHost	=> $config->{ 'bpviewd' }{ 'peer_host' },
  	PeerPort	=> $config->{ 'bpviewd' }{ 'peer_port' },
  	Proto		=> $config->{ 'bpviewd' }{ 'proto' },
  );
  
  my $error = undef;
  
  if (! $socket){
    $error = "Can't connect to API: $!\n";
    return _handle_error( $error );
  }
  
  # send data to server
  if (! $socket->send($json) ){
  	$error = "Can't send data to socket: $!\n";
  	return _handle_error( $error );
  }
  shutdown($socket, 1);
  
  # receive a response of up to 5024 characters from server
  my $response = "";
  
  # fetch all data
  my $tmp_resp = "";
  while (defined $tmp_resp){
    $socket->recv($tmp_resp, $config->{ 'bpviewd' }{ 'response_chars' });
    $response .= $tmp_resp;
    undef $tmp_resp if $tmp_resp eq "";
  }
  
  # close socket
  $socket->close();

  return $response;

}


# get filter from GET parameter
sub _get_filter {

  my $filter = shift or die "Missing filter!";
  
  $log->error_die("Unsupported parameter options: " . $filter) unless ( $filter =~ /^state/ || $filter =~  /^name/);
  my @filterval = split / /, $filter;
      	
  my $filtername = undef;
  my $return = undef;
  
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
    if ( ( $filtername eq "state" ) && ( $filterval[$i] !~ /^[a-zA-Z-]*$/ ) ){
      $log->error_die("Invalid filter option: " . $filterval[$i]);
    }elsif ($filtername eq "state"){
      push @{ $return->{ $filtername } }, $filterval[$i];        
    }
              
              
    # hostname filter
    if ( ( $filtername eq "name" ) && ( $filterval[$i] !~ /^[a-zA-Z0-9_.-]*$/ ) ){
      $log->error_die("Invalid filter characters option: " . $filterval[$i]);
    }elsif ($filtername eq "name"){
      push @{ $return->{ $filtername } }, $filterval[$i];
    }
              
  }
  
  return $return;
        
}


# handle error messages
sub _handle_error {

  my $msg->{ 'error' } = shift or die "Missing error message in function _handle_error!\n";

  # write issue into log file
  $log->error($msg->{ 'error' });
  
  # make output more pretty for users
  $msg->{ 'error' } =~ s/\n/<br>/g;
  $msg->{ 'error' } =~ s/:  at.*//;
  
  my $json = JSON::PP->new->pretty;
  $json->utf8('true');
  $json = $json->encode($msg);
  return $json;
  
}

exit 0;
