!/usr/bin/perl -w
#
# COPYRIGHT:
#
# This software is Copyright (c) 2013 by ovido
#                            (c) 2014 by BPView Development Team
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


package Plugins::IDO;

BEGIN {
    $VERSION = '1.000'; # Don't forget to set version and release
}  						# date in POD below!

use strict;
use warnings;
use Carp;
use JSON::PP;

# for debugging only
#use Data::Dumper;


sub new {
  my $invocant	= shift;
  my $class		= ref($invocant) || $invocant;
  my $self		= {};
 
  bless $self, $class;
  return $self;
}


# parse config parameters
sub parse {
	
  # TODO: later
 
}


# return all data from a monitoring system
sub get {

  # TODO: later

}
