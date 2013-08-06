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

# make sure we are in a sane environment.
$ENV{MOD_PERL} =~ /mod_perl/ or die "MOD_PERL not used!";

use CGI;
use CGI::Carp;
use Apache::DBI;

# Configuration
my $host		= 'localhost';
my $port		= 3306;
my $type		= 'mysql';
my $database	= 'icinga';
my $username	= 'icinga';
my $password	= 'icinga';


Apache::DBI->connect_on_init("DBI:$type:database=$database;host=$host;port=$port", $username, $password);

# enable/disable debug output
$Apache::DBI::DEBUG = 0;

1;