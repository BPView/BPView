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

use Template;
use Data::Dumper;
use CGI qw(param);
use CGI::Carp qw(fatalsToBrowser);
use CGI::Session;

# load custom Perl modules
use lib "../lib";
use BPView::Config;
use BPView::Data;
use BPView::Web;

# global variables
my $session_cache	= 3600;		# 1 hour
my $config;
my $views;
my $dashboards;

# HTML code
print "Content-type: text/html\n\n";

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
my $conf = BPView::Config->new;
if (! $session->param('config')){
  $config = $conf->readDir("../etc");
  $session->param('config', $config);
}else{
  $config = $session->param('config');
}

if (! $session->param('views')){
  $views = $conf->readDir("../etc/views");
  $dashboards = $conf->getDashboards($views);
  
  $session->param('views', $views);
  $session->param('dashboards', $dashboards);
}else{
  $views = $session->param('views');
  $dashboards = $session->param('dashboards');
}


# process URL
if (defined param){
	
	
  my $json = undef;
  
#  print Dumper $config;

  if (defined param("data")){
#  	print "Param: " . param("data") . "<br>\n";
#    # how to handle config here???
#    print "Content-type: application/json charset=iso-8859-1\n\n";
    
#    # get data connection to use
#    my $data_provider = $conf->getProvider( %{ $config->{ 'datasource' } });
#    
#    # get data
#    $json = BPView::Data->new(
#		$data_provider,
#    	views		=> $views,
#    	dashboard	=> param("data"),
#    );	

  }else{
  	print "Unknown paramater!\n";
  	exit 1;
  }
  
# print $json;
 exit 0;
  
}

# TODO:
#             BPView::Config->parse;

#print "Content-type: text/html\n\n";

# display web page
my $page = BPView::Web->new(
 	src_dir		=> $config->{ 'bpview' }{ 'bpview' }{ 'src_dir' },
 	data_dir	=> $config->{ 'bpview' }{ 'bpview' }{ 'data_dir' },
 	site_url	=> $config->{ 'bpview' }{ 'bpview' }{ 'site_url' },
 	template	=> $config->{ 'bpview' }{ 'bpview' }{ 'template' },
);
#   $page->login();
   $page->displayPage(
    page		=> "main",
    dashboards	=> $dashboards,
);



#use vars qw(%Config $logger);
#
#Log::Log4perl::init( $Config{logging}{logfile} );
#my $logger = Log::Log4perl::get_logger();
#$logger->level($Config{logging}{level});


exit 0;
