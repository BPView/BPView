#!/usr/bin/perl -w
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


package Plugins::Livestatus;

BEGIN {
    $VERSION = '1.000'; # Don't forget to set version and release
}  						# date in POD below!

use strict;
use warnings;
use Carp;
use JSON::PP;
use Monitoring::Livestatus;

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
	
  my $self = shift;
  
  # requires socket or server
  if (! $config->{'socket'} && ! $config->{'server'}){
     	
    croak "mk-livestatus: Missing server or socket!";
       
  }else{
     	
    if ($config->{'server'}){
      croak "mk-livestatus: Missing port!" unless $config->{'port'};
    }
       
  }
 
}


# return all data from a monitoring system
sub get {
	
  my $self = shift;
  my $result;
  my $ml;
  
  # construct livestatus query
  my $query = "GET services\n
Columns: host_name description last_hard_state plugin_output\n";

  # TODO: Where to get these data?
  
  # use socket or hostname:port?
  if ($self->{'provdata'}{'socket'}){
    $ml = Monitoring::Livestatus->new( 	'socket' 	=> $self->{'provdata'}{'socket'},
    									'keepalive' => 1 );
  }else{
    $ml = Monitoring::Livestatus->new( 	'server' 	=> $self->{'provdata'}{'server'} . ':' . $self->{'provdata'}{'port'},
    									'keepalive'	=> 1 );
  }
  
  $ml->errors_are_fatal(0);

  # fetch all data and return array
  my $tmp = $ml->selectall_arrayref($query);
  for (my $i=0; $i<scalar @{ $tmp }; $i++ ){
  	
  	# TODO: Convert status to new internal stati
  	
    my $tmphash = {};
    $tmphash->{ 'service' }  = $tmp->[$i][1];
    $tmphash->{ 'state' }    = $tmp->[$i][2];
    $tmphash->{ 'hostname' } = $tmp->[$i][0];
    $tmphash->{ 'output' }   = $tmp->[$i][3];
    # set last hard state to 2 (critical) if host check is 1 (down)
    if ($tmphash->{ 'service' } eq "__HOSTCHECK"){
      $tmphash->{ 'state' } = 2 if $tmp->[$i][2] != 0; 
    }
    push @{ $result->{ $tmp->[$i][0] } }, $tmphash;
  
    # example output:
    # $VAR1 = {
    #         'loadbalancer' => [
    #           {
    #             'service' => 'PING',
    #             'state' => '0',
    #             'hostname' => 'loadbalancer',
    #             'output' => ''
    #           },
    #         ]
    #         },
  }

  if($Monitoring::Livestatus::ErrorCode) {
    die "Getting Monitoring checkresults failed: $Monitoring::Livestatus::ErrorMessage";
  }
 
  return $result;
  
}


1;
