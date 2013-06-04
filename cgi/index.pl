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
use BPView::Web;

# global variables
my $session_cache	= 3600;		# 1 hour
my $config;
my $views;

# HTML code
print "Content-type: text/html\n\n";

# CGI sessions
my $post	= CGI->new;
my $sid     = $post->cookie("CGISESSID") || undef;
my $session = new CGI::Session(undef, $sid, {Directory=>File::Spec->tmpdir});
   $session->expire('config', $session_cache);
   $session->expire('views', $session_cache);
my $cookie  = $post->cookie(CGISESSID => $session->id);
#print $post->header( -cookie=>$cookie );

# open config files if not cached
#my $config = BPView::Config->new;
if (! $session->param('config')){
  $config = BPView::Config->readdir("../etc");
  $session->param('config', $config);
}else{
  $config = $session->param('config');
}

if (! $session->param('views')){
  $views = BPView::Config->readdir("../etc/views");
  $session->param('views', $views)
}else{
  $views = $session->param('views');
}

# TODO:
#             BPView::Config->parse;

# display web page
my $page = BPView::Web->new(
 	src_dir		=> $config->{ 'bpview' }{ 'bpview' }{ 'src_dir' },
 	data_dir	=> $config->{ 'bpview' }{ 'bpview' }{ 'data_dir' },
 	site_url	=> $config->{ 'bpview' }{ 'bpview' }{ 'site_url' },
 	template	=> $config->{ 'bpview' }{ 'bpview' }{ 'template' },
);
#   $page->login();
   $page->display_page( "main" );



#use vars qw(%Config $logger);
#
#Log::Log4perl::init( $Config{logging}{logfile} );
#my $logger = Log::Log4perl::get_logger();
#$logger->level($Config{logging}{level});



exit 0;
