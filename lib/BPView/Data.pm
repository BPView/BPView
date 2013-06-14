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


=head1 NAME

  BPView::Config - Initialize the config parameter

=head1 SYNOPSIS

  use BPView::Config;
  my $ReadConfig = BPView::Config->read("FILENAME");

=head1 DESCRIPTION


=head1 METHODS


=cut


package BPView::Data;

use strict;
use warnings;
use YAML::Syck;
use Carp;
use File::Spec;
use Data::Dumper;


# create an empty BPView::Data object
sub new {
  my $class = shift;
  my $self = {};
  
  bless $self, $class;
  
  return $self;
}


#  use JSON::PP;
#  my $json_data = JSON::PP->new->pretty;
#  my $mydata = {
#  	"hans"	=> "mueller",
#  	"sepp"	=> "bauer"
#  };
#    print $json_data->encode($mydata);

1;
