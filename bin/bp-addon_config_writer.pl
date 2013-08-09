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

# open config files if not cached
my $conf = BPView::Config->new();

# open config file directory and push configs into hash
my $bp_configs = $conf->read_dir( dir	=> $cfg_path . "/bp-config" );

# replaces possible arrays in views with hashes
# TODO: Change process_views, write a new sub or forget it, I dont know.
#$bp_configs = $conf->process_views( 'config' => $bp_configs );


my $dashboards = $conf->get_dashboards( 'config' => $bp_configs );




print "===========================================\n";
print Dumper($dashboards);
print "===========================================\n";



exit 0;