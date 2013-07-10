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
use CGI::Carp qw(fatalsToBrowser);
use File::Spec;
use JSON::PP;
use DBI;

# for debugging only
use Data::Dumper;


# create an empty BPView::Data object
sub new {
  my $invocant	= shift;
  my $class 	= ref($invocant) || $invocant;
  my %options	= @_;
    
  my $self 		= {
  	"views"		=> undef,	# views object (hash)
  	"provider"	=> "ido",	# provider (ido | mk-livestatus)
  	"provdata"	=> undef,	# provider details like hostname, username,... 
	"verbose"	=> 0,		# enable verbose output
  };
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
  
  # parameter validation
  # TODO!
  
  bless $self, $class;
  return $self;
}


# get data
sub get_status {
	
  my $self		= shift;
  my %options 	= @_;
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
  
  my $service_names;
  # go through views hash
  # name required for BP is -> environment-group-product
  foreach my $environment (keys %{ $self->{ 'views' } }){
  	foreach my $groups (keys %{ $self->{ 'views' }{ $environment } }){
      foreach my $product (keys %{ $self->{ 'views' }{ $environment }{ $groups } }){
      	my $bp = $environment . "-" . $groups . "-" . $product;
      	# replace non-chars with _ except -, due to Nagios limitations
        #$bp =~ s/[^a-zA-Z0-9-]+/_/g;
        $bp =~ s/[^a-zA-Z0-9-]/_/g;
  	  	push @{ $service_names }, $bp;
  	  }
  	}
  }
  
  my $return = undef;
  # fetch data from Icinga/Nagios
  if ($self->{'provider'} eq "ido"){
  	
  	# construct SQL query
  	my $sql = $self->_query_ido( $service_names );
  	# get results
  	my $result = $self->_get_ido( $sql );
  	
    if ($self->{'errors'}){
      # TODO!!!
      return 1;
    }
    
    # verify if status is given for all products
    # note: if product is missing in Icinga/Nagios there's no state for it
    # we use status code 99 for this (0-3 are reserved as Nagios plugin exit codes)
    # this is ugly - can it be done better?
    foreach my $environment (keys %{ $self->{ 'views' } }){
  	  foreach my $groups (keys %{ $self->{ 'views' }{ $environment } }){
  	    foreach my $product (keys %{ $self->{ 'views' }{ $environment }{ $groups } }){
  	      # see _get_ido for example output!
  	      my $service = $environment . "-" . $groups . "-" . $product;
  	      # replace non-chars with _ except -, due to Nagios limitations
          #$service =~ s/[^a-zA-Z0-9-]+/_/g;
          $service =~ s/[^a-zA-Z0-9-]/_/g;
  	  	  if (defined ($result->{ $service }{ 'state' })){
  	  	  	# found status in IDO database
	      	$self->{ 'views' }{ $environment }{ $groups }{ $product }{ 'state' } = $result->{ $service }{ 'state' };
	      }else{
	      	# didn't found status in IDO database
	      	$self->{ 'views' }{ $environment }{ $groups }{ $product }{ 'state' } = 99;
	      }
  	    }
  	  }
    }
    
  	
  }elsif ($self->{'provider'} eq "mk-livestatus"){
  	# TODO: later!
  	
  }else{
  	carp ("Unsupported provider: $self->{'provider'}!");
  }
  
  
  # produce json output
  my $json = JSON::PP->new->pretty;
  $json = $json->sort_by(sub { $JSON::PP::a cmp $JSON::PP::b })->encode($self->{ 'views' });

  return $json;
  
}


# internal methods
##################

# construct SQL query for IDOutils
sub _query_ido {
	
  my $self			= shift;
  my $service_names	= shift or croak ("Missing service_names!");
  
  # construct SQL query
  # TODO: validate if it's working with PostreSQL and MySQL!
  my $sql = "SELECT name2 AS service, current_state AS state FROM " . $self->{'provdata'}{'prefix'} . "objects, " . $self->{'provdata'}{'prefix'} . "servicestatus ";
    $sql .= "WHERE object_id = service_object_id AND is_active = 1 AND name2 IN (";
  # go trough service_names array
  for (my $i=0;$i<scalar @{ $service_names };$i++){
  	$sql .= "'" . $service_names->[$i] . "', ";
  }
  # remove trailing ', '
  chop $sql;
  chop $sql; 
  $sql .= ") ORDER BY name1";
  
  return $sql;
  
}


# get service status from IDOutils
sub _get_ido {
	
  my $self	= shift;
  my $sql	= shift or croak ("Missing SQL query!");
  
  my $result;
  
  my $dsn = undef;
  # database driver
  if ($self->{'provdata'}{'type'} eq "mysql"){
  	$dsn = "DBI:mysql:database=$self->{'provdata'}{'database'};host=$self->{'provdata'}{'host'};port=$self->{'provdata'}{'port'}";
  }elsif ($self->{'provdata'}{'type'} eq "postgresql"){
  	
  }else{
  	croak "Unsupported database type: $self->{'provdata'}{'type'}";
  }
  
  # connect to database
  my $dbh   = DBI->connect($dsn, $self->{'provdata'}{'username'}, $self->{'provdata'}{'password'});
  if ($DBI::errstr){
  	push @{ $self->{'errors'} }, "Can't connect to database: $DBI::errstr";
  	return 1;
  }
  my $query = $dbh->prepare( $sql );
  $query->execute;
  if ($DBI::errstr){
  	push @{ $self->{'errors'} }, "Can't execute query: $DBI::errstr";
    $dbh->disconnect;
  	return 1;
  }
  
  # prepare return
  $result = $query->fetchall_hashref('service');
  
  # example output:
  # $VAR1 = {
  #        'production-mail-zarafa' => {
  #                                      'service' => 'production-mail-zarafa',
  #                                      'state' => '0'
  #                                    },
  
  
  # disconnect from database
  $dbh->disconnect;
  
  return $result;
  
}

1;
