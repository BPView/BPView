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

#use Log::Log4perl qw(:easy);

use lib "../lib";
use BPView::Config;

# HTML code
print "Content-type: text/html\n\n";

# open config files
my $config = BPView::Config->new;
   $config = BPView::Config->readdir("../etc");
my $views  = BPView::Config->readdir("../etc/views");
# TODO:
#             BPView::Config->parse;

print "<pre>";
print Dumper $config;
print Dumper $views;
print "</pre>";





#use vars qw(%Config $logger);
#
#Log::Log4perl::init( $Config{logging}{logfile} );
#my $logger = Log::Log4perl::get_logger();
#$logger->level($Config{logging}{level});



exit 0;
