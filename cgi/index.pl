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
use CGI::Carp qw(fatalsToBrowser);
use CGI::Session;


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


# global variables
my $session_cache	= 3600;		# 1 hour
my $config;
my $views;
my $dashboards;


# HTML code
print "Content-type: text/html\n\n" unless defined param;

# CGI sessions
my $post	= CGI->new;
my $sid     = $post->cookie("CGISESSID") || undef;
my $session = new CGI::Session(undef, $sid, {Directory=>File::Spec->tmpdir});
   $session->expire('config', $session_cache);
   $session->expire('views', $session_cache);
   $session->expire('dashboards', $session_cache);
my $cookie  = $post->cookie(CGISESSID => $session->id);
#print $post->header( -cookie=>$cookie );


# open config files if not cached
my $conf = BPView::Config->new();

if (! $session->param('config')){
  
  # open config file directory and push configs into hash
  $config = $conf->read_dir( dir => $cfg_path );
  # validate config
  exit 1 unless ( $conf->validate( 'config' => $config ) == 0);
  # cache config
  $session->param('config', $config);
  
}else{

  # use cached config
  $config = $session->param('config');
  
}

if (! $session->param('views')){
  $views = $conf->read_dir( dir	=> $cfg_path . "/views" );
  # replaces possible arrays in views with hashes
  $views = $conf->process_views( 'config' => $views );
  $dashboards = $conf->get_dashboards( 'config' => $views );
  
  $session->param('views', $views);
  $session->param('dashboards', $dashboards);
}else{
  $views = $session->param('views');
  $dashboards = $session->param('dashboards');
}


# process URL
if (defined param){
	
  # JSON Header
  print "Content-type: application/json charset=iso-8859-1\n\n";
  my $json = undef;
  
  if (defined param("dashboard")){
  	
    # get dashboard data
    my $dashboard = BPView::Data->new(
    	 views		=> $views->{ param("dashboard") }{ 'views' },
    	 provider	=> $config->{ 'provider' }{ 'source' },
    	 provdata	=> $config->{ $config->{ 'provider' }{ 'source' } },
       );	
    $json = $dashboard->get_status();
       
  }elsif (defined param("details")){
  	
  	# get details for this business process
  	my $details = BPView::Data->new(
  		provider	=> 'bpaddon',
  		provdata	=> $config->{ 'bpaddon' },
  		bp			=> param("details"),
  	   );
  	$json = $details->get_details();
  	
  }else{
  	
  	print "Unknown paramater!\n";
  	exit 1;
  	
  }
  
  print $json;
  exit 0;
  
}

#print "Content-type: text/html\n\n";

# display web page
my $page = BPView::Web->new(
 	src_dir		=> $config->{ 'bpview' }{ 'src_dir' },
 	data_dir	=> $config->{ 'bpview' }{ 'data_dir' },
 	site_url	=> $config->{ 'bpview' }{ 'site_url' },
 	template	=> $config->{ 'bpview' }{ 'template' },
);
#   $page->login();
   $page->display_page(
     page		=> "main",
     content	=> $dashboards,
     refresh	=> $config->{ 'refresh' }{ 'interval' },
);


exit 0;
