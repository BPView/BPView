#!/usr/bin/perl -w
#
# COPYRIGHT:
#
# This software is Copyright (c) 2013 by ovido
#                            (c) 2014-2015 BPView Development Team
#                                     http://github.com/BPView/BPView
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


package BPView::Data;

BEGIN {
    $VERSION = '2.000'; # Don't forget to set version and release
}  						# date in POD below!

use strict;
use warnings;
use YAML::Syck;
use Carp;
use Cache::Memcached;
use File::Spec;
use File::stat;
use JSON::PP;
use Tie::IxHash;
use Storable 'dclone';
use POSIX qw( strftime );
use Module::Pluggable search_path => "Plugins", instantiate => 'new';;

use constant DISPLAY => '__display';
use constant TOPICS => '__topics';
use constant VIEWS => 'views';

# for debugging only
use Data::Dumper;


=head1 NAME

  BPView::Data - Connect to data backend

=head1 SYNOPSIS

  use BPView::Data;
  my $details = BPView::Data->new(
  		provider	=> 'ido',
  		provdata	=> $provdata,
  		views		=> $views,
  	 );
  $json = $details->get_status();

=head1 DESCRIPTION

This module fetches business process data from various backends like
IDOutils and mk-livestatus.

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an BPView::Data object. <new> takes at least the provider and 
provdata. Arguments are in key-value pairs.
See L<EXAMPLES> for more complex variants.

=over 4

=item provider

name of datasource provider (supported: ido|bpaddon)

=item provdata

provider specific connection data

IDO:
  host: hostname (e.g. localhost)
  port: port (e.g. 3306)
  type: mysql|pgsql
  database: database name (e.g. icinga)
  username: database user (e.g. icinga)
  password: database password (e.g. icinga)
  prefix: database prefix (e.g. icinga_)
  
=item views

hash reference of view config
required for BPView::Data->get_status()

=item bp

name of business process to query service details from
required for BPView::Data->get_details()

=cut


sub new {
  my $invocant	= shift;
  my $class 	= ref($invocant) || $invocant;
  my %options	= @_;
    
  my $self 		= {
  	"views"		=> undef,	# views object (hash)
  	"bp"		=> undef,	# name of business process
#  	"provider"	=> "ido",	# provider (ido | mk-livestatus)
#  	"provdata"	=> undef,	# provider details like hostname, username,... 
  	"config"	=> undef,
  	"bps"		=> undef,
  	"filter"	=> undef,	# filter states (e.g. don't display bps with state ok)
  	"cache"		=> undef,	# memcached object
  	"log"		=> undef,	# log file
  	"mappings"	=> undef,	# status map
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
  # don't use views and bps together
  if (defined $self->{ VIEWS() } && defined $self->{ 'bp' }){
  	croak ("Can't use views and bp together!");
  }
  
  chomp $self->{ 'bp' } if defined $self->{ 'bp' };
  
  bless $self, $class;
  return $self;
}


#----------------------------------------------------------------

=head1 METHODS	

=head2 get_status

 get_status ( 'views' => $views )

Connects to backend and queries status of business process.
Business process must be available in memcached!
Returns JSON data.

  my $json = $get_status( 'views' => $views );
  
$VAR1 = {
   "production" : {
       "mail" : {
          "lb" : {
             "bpname" : "production-mail-lb",          	
              "state" : "0"         	
           }
       }
    }
 }                               	

=cut

sub get_status {
	
  my $self		= shift;
  my %options 	= @_;
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  die "Unknown option: $key";
  	}
  }
  
  my $log = $self->{ 'log' };
  
  my $service_names;
  # go through views hash
  # name required for BP is -> environment-group-product
  foreach my $environment (keys %{ $self->{ VIEWS() } }){
  	foreach my $topic (keys %{ $self->{ VIEWS() }{ $environment }{ TOPICS() } }){
		foreach my $product (keys %{ $self->{ VIEWS() }{ $environment }{ TOPICS() }{ $topic } }){
			my $bp = $environment . "-" . $topic . "-" . $product;
			# replace non-chars with _ except -, due to Nagios limitations
			$bp =~ s/[^a-zA-Z0-9-]/_/g;
			push @{ $service_names }, lc($bp);
		}
  	}
  }
  
  my $result = {};
  # fetch data from memcached
  my $cache = $self->{ 'cache' };

  for (my $i=0;$i<=@{ $service_names };$i++){
    $result->{ $service_names->[$i] }{ 'service' }	= $service_names->[$i];
    my $memcache_result = $cache->get( $service_names->[$i] ); # or die "Couldn't fetch data from memcached: $!"; 
    if ($memcache_result){
      $result->{ $service_names->[$i] }{ 'state' }	= $memcache_result->{ "status" };
      $result->{ $service_names->[$i] }{ 'age' }	= $memcache_result->{ "age" };
    }
  }
  
	# sorting the hash 
	my $views = dclone $self->{ VIEWS() };
	my %views_empty;

	while(my($view_key, $view) = each %$views) {
		while(my($topic, $prods) = each %{ $view->{ TOPICS() }}) {
			tie my %new_prods, 'Tie::IxHash', (map { ($_ => $prods->{$_}) } sort { lc($a) cmp lc($b) } keys %$prods);
			$view->{ TOPICS() }{$topic} = \%new_prods;
		}
		
		my %new_view;
		# sort alphabetically
		if($view->{ DISPLAY() }{ 'sort' } eq 'alphabetical'){
			tie %new_view, 'Tie::IxHash', (map { ($_ => $view->{ TOPICS() }{$_}) } sort { lc($a) cmp lc($b) } keys %{ $view->{ TOPICS() }});
		}
		elsif($view->{ DISPLAY() }{ 'sort' } eq 'productnumbers'){
			# sort based on # entries
			tie %new_view, 'Tie::IxHash', (map { ($_ => $view->{ TOPICS() }{$_}) } sort { keys %{ $view->{ TOPICS() }{$b} } <=> keys %{ $view->{ TOPICS() }{$a} } } keys %{ $view->{ TOPICS() }});
		}


		# write new hash
		$views->{$view_key}{ DISPLAY() } = $view->{ DISPLAY() };
		$views->{$view_key}{ TOPICS() } = \%new_view;
		
		# sort hash alphabetically - __display need to be before __topics
		tie my %new_topics, 'Tie::IxHash', (map { ($_ => $views->{$view_key}{$_}) } sort { $a cmp $b } keys %{ $views->{$view_key}});
		$views->{$view_key} = \%new_topics;
		
	}
	tie my %new_views, 'Tie::IxHash', (map { ($_ => $views->{$_}) } sort { $views->{$a}->{ DISPLAY() }{'order'} <=> $views->{$b}->{ DISPLAY() }{'order'} } keys %$views);
	my $viewOut = \%new_views;

	
  # verify if status is given for all products
  # note: if product is missing in Icinga/Nagios there's no state for it
  # we use status code 98 for this (0-3 are reserved as Nagios plugin exit codes)
  
  foreach my $environment (keys %{ $viewOut }){
    foreach my $topic (keys %{ $viewOut->{ $environment }{ TOPICS() } }){
      
      foreach my $product (keys %{ $viewOut->{ $environment }{ TOPICS() }{ $topic } }){
      	
    	  # see _get_ido for example output!
  	    my $service = lc($environment . "-" . $topic . "-" . $product);
  	    # replace non-chars with _ except -, due to Nagios limitations
        $service =~ s/[^a-zA-Z0-9-]/_/g;

    	  if (defined ($result->{ $service }{ 'state' })){
  	      # found status in IDO database
  	      # get status name from mappings config file
  	      foreach my $status (keys %{ $self->{ 'mappings' }}){
  	      	if ($result->{ $service }{ 'state' } eq $self->{ 'mappings' }{ $status }{ 'mapped' }){
	            $viewOut->{ $environment }{ TOPICS() }{ $topic }{ $product }{ 'state' } = $status;
  	      	}
  	      }
	      }else{
	        # didn't found status in IDO database
  	      $viewOut->{ $environment }{ TOPICS() }{ $topic }{ $product }{ 'state' } = "not-found";
	      }
	    
	      # return also business process name
	      $viewOut->{ $environment }{ TOPICS() }{ $topic }{ $product }{ 'bpname' } = $service;
	      if (defined $self->{ 'bps' }{ $service }{ 'BP' }{ 'NAME' }){
	        $viewOut->{ $environment }{ TOPICS() }{ $topic }{ $product }{ 'name' } = $self->{ 'bps' }{ $service }{ 'BP' }{ 'NAME' };
	      }else{
	        $viewOut->{ $environment }{ TOPICS() }{ $topic }{ $product }{ 'name' } = "Missing BP-Config!";
	      }
	      $viewOut->{ $environment }{ TOPICS() }{ $topic }{ $product }{ 'age' } = $result->{ $service }{ 'age' };
	      
	      # filter objects
	      if (defined $self->{ 'filter' }{ 'state' }){
          # filter results
          my $del = 1;
          for (my $i=0;$i< scalar @{ $self->{ 'filter' }{ 'state' } }; $i++){
            if ($self->{ 'filter' }{ 'state' }->[ $i ] =~ /not/){
              $del = 0;
              my $filter = $self->{ 'filter' }{ 'state' }->[ $i ];
              $filter =~ s/not-//g;
		          delete $viewOut->{ $environment }{ TOPICS() }{ $topic }{ $product } 
		                 if lc($viewOut->{ $environment }{ TOPICS() }{ $topic }{ $product }{ 'state' }) eq lc($filter);
		          next;
		        }else{
			        $del = 0 if lc($viewOut->{ $environment }{ TOPICS() }{ $topic }{ $product }{ 'state' }) eq lc($self->{ 'filter' }{ 'state' }->[$i]);
		        }
		      }
		      delete $viewOut->{ $environment }{ TOPICS() }{ $topic }{ $product } if $del == 1;
		      delete $viewOut->{ $environment }{ TOPICS() }{ $topic }{ $product } if ! defined $viewOut->{ $environment }{ TOPICS() }{ $topic }{ $product }{ 'state' };
	      }
	    
	      # filter hostnames
	      if (defined $self->{ 'filter' }{ 'name' }){
		      my $del = 1;
		      # loop through hostname hash
		      foreach my $hostname (keys %{ $self->{ 'bps' }{ $service }{ 'HOSTS' } }){
	          for (my $i=0;$i< scalar @{ $self->{ 'filter' }{ 'name' } }; $i++){
	            $del = 0 if lc( $hostname ) =~ lc ( $self->{ 'filter' }{ 'name' }->[ $i ]);
        	  }
          }
          delete $viewOut->{ $environment }{ TOPICS() }{ $topic }{ $product } if $del == 1;
	      }
	      
      }
      
      # delete empty topics
      delete $viewOut->{ $environment }{ TOPICS() }{ $topic} if scalar keys %{ $viewOut->{ $environment }{ TOPICS() }{ $topic } } == 0;
      
    }
    
    # delete empty environments
    delete $viewOut->{ $environment } if scalar keys %{ $viewOut->{ $environment }{ TOPICS() } } == 0;
    
  }

  # produce json output
  my $json = JSON::PP->new->pretty;
  $json->utf8('true');
  $json = $json->encode($viewOut);
  return $json;
  
}


#----------------------------------------------------------------

=head1 METHODS	

=head2 get_bpstatus

 get_bpstatus ( )

Connects to backend and queries status of all host and service checks.
Returns hash.

  my $hash = $details->get_status();                               	

$VAR1 = {
  'loadbalancer' => [
    {
      'name2' => 'Service State Check',
      'last_hard_state' => '0',
      'hostname' => 'loadbalancer',
      'output' => 'OK: All services are in their appropriate state.'
    },
  ],
}  

=cut

sub get_bpstatus {
	
  my $self		= shift;
  my %options 	= @_;
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
  
  my $result = undef;
  
  my $log = $self->{ 'log' };
  
  # loop through providers
  foreach my $provider (keys %{ $self->{ 'config' } }){
  	
  	# skip bpviewd config
  	next if $provider eq 'bpviewd';
  	
    # verify if we cache data 
  	if (defined $self->{ 'config' }{ $provider }{ 'cache_file' }){
#  	  # caching disabled if 0 or no cache time defined
#      if (! defined $self->{ 'config' }{ $provider }{ 'cache_time' } || $self->{ 'config' }{ $provider }{ 'cache_time' } == 0){
#      	#    $self->query_provider();
#      }
      $log->debug("Using cache file $self->{ 'config' }{ $provider }{ 'cache_file' }");
#      $result->{ $provider } = $self->_open_cache( $self->{ 'config' }{ $provider }{ 'cache_time' }, $self->{ 'config' }{ $provider }{ 'cache_file' } );
      $result->{ $provider } = $self->_open_cache( $self->{ 'config' }{ $provider }{ 'cache_file' } );

      # query next provider
###      next unless $result->{ $provider } == 1;
#    }else{
      #    $self->query_provider();
    }

  }
  return $result;
  
}


#----------------------------------------------------------------

=head1 METHODS	

=head2 get_bpdetails

 get_bpdetails ( $bp_name )

Returns service details for given business process.
Returns hash.

  my $hash = $details->get_bpdetails( $bp_name );                               	

$VAR1 = {
   "mailserver": {
      "Amavisd-new Virus Check" : {
         "hardstate" : "OK",
         "output" : "Amavisd-New Virusscanning OK - server returned 2.7.0 Ok, discarded, id=00848-16 - INFECTED: Eicar-Test-Signature",
         "acknowledged" : 0,
         "downtime" : 0,
         "outdated" : 0
      },
   },
}

=cut

sub get_bpdetails {
	
  my $self		= shift;
  my $bp_name	= shift or croak "Missing business process name!";
  my %options 	= @_;
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
  
  my $status = eval { $self->get_bpstatus() };
  croak "Failed to receive BP stati.\nReason: $@" if $@;
  
  my $return = {};
  
  croak "No data received from backend!" unless $status;
  
  my $log = $self->{ 'log' };
 
  my $provider = undef;
  # which backend provider do we use?
  if (defined $self->{ 'bps' }{ $self->{ 'bp' } }{ 'BP' }{ 'PROVIDER' }){
  	$provider = $self->{ 'bps' }{ $self->{ 'bp' } }{ 'BP' }{ 'PROVIDER' };
  }else{
  	# use default one
  	$provider = $self->{ 'config' }{ 'default' }{ 'source' };
  }
  
  $log->info("Provider: $provider");
  
  foreach my $host (keys %{ $self->{ 'bps' }{ $self->{ 'bp' } }{ 'HOSTS' } }){
    foreach my $service (keys %{ $self->{ 'bps' }{ $self->{ 'bp' } }{ 'HOSTS' }{ $host } }){
    	
      # Check if host array is empty - this happens if host was not found in monitoring system
      if (defined $status->{ $provider }{ $host }){
      	
        # loop through host array
        for (my $i=0; $i< scalar @{ $status->{ $provider }{ $host } }; $i++){
      	  if ($status->{ $provider }{ $host }->[ $i ]->{ 'name2' } eq $service){
      	    # service found
      	    my $state = "not-found";
      	    # get status name from mappings config file
  	        foreach my $map_status (keys %{ $self->{ 'mappings' }}){
  	      	  if ($status->{ $provider }{ $host }->[ $i]->{ 'last_hard_state' } eq $self->{ 'mappings' }{ $map_status }{ 'mapped' }){
	            $state = $map_status;
  	      	  }
  	        }
  	        my $last_check = $status->{ $provider }{ $host }->[ $i ]->{ 'last_check' };
  	        my $date = time();
      	    $return->{ $host }{ $service }{ 'hardstate' } = $state;
     	      $return->{ $host }{ $service }{ 'output' } = $status->{ $provider }{ $host }->[ $i ]->{ 'output' };
     	      $return->{ $host }{ $service }{ 'last_check' } = strftime("%Y-%m-%d %H:%M:%S", localtime( $last_check ) );
     	      $return->{ $host }{ $service }{ 'downtime' } = $status->{ $provider }{ $host }->[ $i ]->{ 'downtime' };
     	      $return->{ $host }{ $service }{ 'acknowledged' } = $status->{ $provider }{ $host }->[ $i ]->{ 'acknowledged' };
     	      if ($date - $last_check > $self->{ 'config' }{ 'bpviewd' }{ 'outdated_time' }){
     	        $return->{ $host }{ $service }{ 'outdated' } = 1;
     	      }else{
     	        $return->{ $host }{ $service }{ 'outdated' } = 0;
     	      }
      	  }
        }
        
        # service not found
        if (! defined $return->{ $host }{ $service }{ 'hardstate' } ){
      	  # service missing in data source
      	  $return->{ $host }{ $service }{ 'hardstate' } = "UNKNOWN";
      	  $return->{ $host }{ $service }{ 'output' } = "Service $service not found in Monitoring system!";
      	  $return->{ $host }{ $service }{ 'last_check' } = "UNKNOWN";
	    }
	  
      }else{
      	
      	# Host missing in monitoring system
      	$return->{ $host }{ ' ' }{ 'hardstate' } = "UNKNOWN";
      	$return->{ $host }{ ' ' }{ 'output' } = "Host $host not found in Monitoring system!";
      	$return->{ $host }{ ' ' }{ 'last_check' } = "UNKNOWN";
      	
      }
    }
  }
  
  return $return;
  
}


#----------------------------------------------------------------

=head1 METHODS	

=head2 get_details

 get_details ( 'bp' => $business_process )

Connects to data backend and fetches service status details for all
services of this business process.
Returns JSON data.

  my $json = $get_details( 'bp' => $business_process );
  
$VAR1 = {
   "mailserver": {
      "Amavisd-new Virus Check" : {
         "hardstate" : "OK",
         "output" : "Amavisd-New Virusscanning OK - server returned 2.7.0 Ok, discarded, id=00848-16 - INFECTED: Eicar-Test-Signature"
      },
   },
}

=cut

sub get_details {
	
  my $self		= shift;
  my %options 	= @_;
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
  
  my $log = $self->{ 'log' };
  
# why?
#  if (defined $self->{ 'config' }{ 'provider' }{ 'source' }){
#  	# override provider data to be able to detect host down events
#  	$self->{ 'provider' } = $self->{ 'config' }{ 'provider' }{ 'source' };
#  	$self->{ 'provdata' } = $self->{ 'config' }{ $self->{ 'config' }{ 'provider' }{ 'source' } };
#  }
  
  # Die if no hosts are defined
  croak "No host defined for given business process " . $self->{ 'bp' } unless defined $self->{ 'bps' }{ $self->{ 'bp' } }{ 'HOSTS' };
  
  # get details for given business process 
  my $return = eval { $self->get_bpdetails( $self->{ 'bp' } ) };
  croak "Failed to fetch BP details.\nReason: $@" if $@;
  
  foreach my $host (keys %{ $return }){
		
    # filter objects
    if (defined $self->{ 'filter' }{ 'state' }){
	    foreach my $service (keys %{ $return->{ $host } }){
		    my $del = 1;
	      # filter results
        for (my $i=0;$i< scalar @{ $self->{ 'filter' }{ 'state' } }; $i++){
          if ($self->{ 'filter' }{ 'state' }->[ $i ] =~ /not/){
            $del = 0;
            my $filter = $self->{ 'filter' }{ 'state' }->[ $i ];
            $filter =~ s/not-//g;
            delete $return->{ $host }{ $service }
                 if lc($return->{ $host }{ $service }{ 'hardstate' }) eq lc($filter);
		        next;
		      }else{
			      $del = 0 if lc($return->{ $host }{ $service }{ 'hardstate' }) eq lc($self->{ 'filter' }{ 'state' }->[$i]);
		      }
	      }
		    delete $return->{ $host }{ $service } if $del == 1;
		    delete $return->{ $host }{ $service } if ! defined $return->{ $host }{ $service }{ 'hardstate' };
      }
	    if (scalar keys %{ $return->{ $host } } == 0) {
		    delete $return->{ $host };
	    }
    }
	    
    # filter hostnames
    if (defined $self->{ 'filter' }{ 'name' }){
  	
  	  my $del = 1;
      # loop through hostname hash
  	  foreach my $service (keys %{ $return->{ $host } }){
        for (my $x=0;$x< scalar @{ $self->{ 'filter' }{ 'name' } }; $x++){
          $del = 0 if lc( $host ) =~ lc ( $self->{ 'filter' }{ 'name' }->[ $x ]);
        }
        delete $return->{ $host } if $del == 1
  	  }
    }
    
  }
	    
  # produce json output
  my  $json = JSON::PP->new->pretty;
  $json = $json->sort_by(sub { $JSON::PP::a cmp $JSON::PP::b })->encode($return);
  
  return $json;
  
}

#----------------------------------------------------------------

sub query_provider {

  my $self      = shift;
  my %options   = @_;
  my $result = undef;
  for my $key (keys %options){
        if (exists $self->{ $key }){
          $self->{ $key } = $options{ $key };
        }else{
          croak "Unknown option: $key";
        }
  }
  
  my $log = $self->{ 'log' };
  
  # fetch data
  foreach my $provider (keys %{ $self->{ 'config' } }){
  	if (defined $self->{ 'config' }{ $provider }{ 'provider' }){

      $log->debug("Fetching data for provider " . $provider);
      
      # check if a restart timeout is defined and if monitoring backend
      # provides these data. If yes, skip fetching if backend was restarted
      # restart_timeout seconds ago.
      if (defined $self->{ 'config' }{ 'bpviewd' }{ 'restart_timeout' }){
      	
      	my $restart_timeout = $self->{ 'config' }{ 'bpviewd' }{ 'restart_timeout' };
        my $tmp = $self->_get_restart_time( $self->{ 'config' }{ $provider }, $restart_timeout );
        my $restart = 0;
        foreach my $keys (keys %{ $tmp }){
          $restart = $keys;
          $log->debug("Last restart of monitoring backend: $restart");
        } 
        my $now = time;
        my $online = $now - $restart;
        
        if ($online <= $restart_timeout){
          $log->info("Monitoring backend $provider was restarted " . $online . " seconds ago - skipping provider");
          next;
        }
        
      }

  	  if ($self->{ 'config' }{ $provider }{ 'provider'} eq "ido"){

        # construct SQL query
        my $sql = $self->_query_ido( $self->{ 'config' }{ $provider }, '__all' );
        # get results
        $result = eval { $self->_get_ido( $self->{ 'config' }{ $provider }, $sql, "row" ) };
        if ($@){
          $log->error("Failed to fetch data from IDO: " . $@);
          next;
        }else{
          $log->debug("Successfully fetched data from IDO");
        }

  	  }elsif ($self->{ 'config' }{ $provider }{'provider'} eq "mk-livestatus"){

		# TODO: change to Plugin

        # construct query
        my $query = $self->_query_livestatus( '__all' );
        # get results
        $result = eval { $self->_get_livestatus( $self->{ 'config' }{ $provider }, $query, "row" ) };
        if ($@){
          $log->error("Failed to fetch data from livestatus: " . $@);
          next;
        }else{
          $log->debug("Successfully fetched data from livestatus");
        }

  	  }else{
        carp ("Unsupported provider: $self->{ 'config' }{ $provider }{ 'provider'}!");
      }
      
      
      # handle status mapping
      foreach my $host (keys %{ $result }){
       
        # handle host checks
        # we need to override services if host check is acknowledged or in a scheduled
        # downtime
        my $downtime = 0;
        my $acknowledged = 0;
      	for (my $i=0;$i< scalar @{ $result->{ $host } };$i++){
      	  next unless $result->{ $host }->[ $i ]->{ 'name2' } eq "__HOSTCHECK";
      	  $downtime = $result->{ $host }->[ $i ]->{ 'downtime' } if defined $result->{ $host }->[ $i ]->{ 'downtime' };
      	  $acknowledged = $result->{ $host }->[ $i ]->{ 'acknowledged' } if defined $result->{ $host }->[ $i ]->{ 'acknowledged' };
      	}
      	
      	# handle all services
      	for (my $i=0;$i< scalar @{ $result->{ $host } };$i++){
 
          # override downtimes and acknowledgements for services if host is acknowledged
          # or in scheduled downtime
          if ($downtime == 0){
            $downtime = $result->{ $host }->[ $i ]->{ 'downtime' } if defined $result->{ $host }->[ $i ]->{ 'downtime' };
          }else{
            $result->{ $host }->[ $i ]->{ 'downtime' } = $downtime;
          }
          if ($acknowledged == 0){
      	    $acknowledged = $result->{ $host }->[ $i ]->{ 'acknowledged' } if defined $result->{ $host }->[ $i ]->{ 'acknowledged' };
          }else{
            $result->{ $host }->[ $i ]->{ 'acknowledged' } = $acknowledged;
          }
      	  $acknowledged = $result->{ $host }->[ $i ]->{ 'acknowledged' } if defined $result->{ $host }->[ $i ]->{ 'acknowledged' } && $acknowledged != 0;
      	  my $status = 3;
      	     $status = $result->{ $host }->[ $i ]->{ 'last_hard_state' } if defined $result->{ $host }->[ $i ]->{ 'last_hard_state' };
      	     
      	  # remove duplicates, but keep schedules downtimes
      	  if ($result->{ $host }->[ $i ]->{ 'name2' } eq $result->{ $host }->[ $i-1 ]->{ 'name2' }){
      	    if ($downtime == 1){
      	      delete $result->{ $host }->[ $i-1 ];
      	    }else{
      	      delete $result->{ $host }->[ $i ];
      	      next;
      	    }
      	  }
      	  
      	  # go through mappings config
      	  foreach my $state (keys %{ $self->{ 'mappings' } }){
      	  	# TODO: check provider
      	  	if ( $self->{ 'mappings' }{ $state }{ 'status' } ne $status ){
      	  	  # original states don't match - skip it
      	  	  next;
      	  	}
      	  	# TODO: try to avoid hard coded __HOSTCHECK here!
      	  	if ( $result->{ $host }->[ $i ]->{ 'name2' } eq "__HOSTCHECK" ){
      	  	  # skip this services if a special service name (e.g. __HOSTCHECK) is configured,
      	  	  # but the actual service doesn't match
      	  	  next unless $self->{ 'mappings' }{ $state }{ 'service' } eq $result->{ $host }->[ $i ]->{ 'name2' };
      	  	}else{
      	  	  # skip service stati with defined services
      	  	  next if defined $self->{ 'mappings' }{ $state }{ 'service' };
      	  	}
      	  	if (( $self->{ 'mappings' }{ $state }{ 'downtime' } eq $downtime ) && ( $downtime ne 0 )){
      	  	  # we found a scheduled downtime - change original state of service
      	      $log->debug("Mapping service state of \"" . $result->{ $host }->[ $i ]->{ 'name2' } . "\" [$host] from " . $result->{ $host }->[ $i ]->{ 'last_hard_state' } . " to " . $self->{ 'mappings' }{ $state }{ 'mapped' });
      	      $result->{ $host }->[ $i ]->{ 'last_hard_state' } = $self->{ 'mappings' }{ $state }{ 'mapped' };
      	  	}elsif (( $self->{ 'mappings' }{ $state }{ 'acknowledged' } eq $acknowledged ) && ( $acknowledged ne 0 ) && ( $downtime eq 0 )){
      	  	  # acknowledgements are less important as scheduled downtimes
      	  	  next if $self->{ 'mappings' }{ $state }{ 'downtime' } ne 0;
      	  	  $log->debug("Mapping service state of \"" . $result->{ $host }->[ $i ]->{ 'name2' } . "\" [$host] from " . $result->{ $host }->[ $i ]->{ 'last_hard_state' } . " to " . $self->{ 'mappings' }{ $state }{ 'mapped' });
      	      $result->{ $host }->[ $i ]->{ 'last_hard_state' } = $self->{ 'mappings' }{ $state }{ 'mapped' };
      	  	}elsif ($downtime eq 0 && $acknowledged eq 0){
      	  	  # we have neither scheduled downtime nor an acknowledgement
      	  	  next if $self->{ 'mappings' }{ $state }{ 'acknowledged' } ne 0;
      	  	  next if $self->{ 'mappings' }{ $state }{ 'downtime' } ne 0;
      	  	  $log->debug("Mapping service state of \"" . $result->{ $host }->[ $i ]->{ 'name2' } . "\" [$host] from " . $result->{ $host }->[ $i ]->{ 'last_hard_state' } . " to " . $self->{ 'mappings' }{ $state }{ 'mapped' });
      	      $result->{ $host }->[ $i ]->{ 'last_hard_state' } = $self->{ 'mappings' }{ $state }{ 'mapped' };
      	  	}
      	  	  
      	  }
      	  
      	}
      }
 
      $self->_write_cache( $self->{ 'config' }{ $provider }{ 'cache_file' }, $result );
      
  	}
  }
}



#----------------------------------------------------------------

# internal methods
##################

# construct SQL query for IDOutils
sub _query_ido {
	
  my $self			= shift;
  my $provdata		= shift or die ("Missing provdata!");
  my $service_names	= shift or die ("Missing service_names!");
  
  my $sql = undef;
  
  # construct SQL query
  # query all host and service data
  if ($service_names eq "__all"){

=cut
Example query: Fetch host and service checks, acknowledges and scheduled downtimes
--------------

SELECT DISTINCT
	icinga_objects.name1 AS hostname,
	coalesce(icinga_objects.name2,'__HOSTCHECK') AS name2,
  coalesce(icinga_hoststatus.last_hard_state, icinga_servicestatus.last_hard_state) AS last_hard_state,
  coalesce(icinga_hoststatus.problem_has_been_acknowledged, icinga_servicestatus.problem_has_been_acknowledged) AS acknowledged, 
	coalesce(icinga_hoststatus.output, icinga_servicestatus.output) AS output,
	coalesce(unix_timestamp(icinga_hoststatus.last_check), unix_timestamp(icinga_servicestatus.last_check)) AS last_check,
	unix_timestamp() between unix_timestamp(icinga_scheduleddowntime.scheduled_start_time) AND
	unix_timestamp(icinga_scheduleddowntime.scheduled_end_time) AS downtime
FROM 
	icinga_objects
LEFT JOIN
	icinga_scheduleddowntime 
  ON icinga_scheduleddowntime.object_id = icinga_objects.object_id
LEFT JOIN 
	icinga_hoststatus 
  ON icinga_objects.object_id=icinga_hoststatus.host_object_id
LEFT JOIN 
	icinga_servicestatus
  ON icinga_objects.object_id=icinga_servicestatus.service_object_id 
WHERE
	icinga_objects.is_active = 1
  AND (icinga_objects.objecttype_id=1 
  OR icinga_objects.objecttype_id=2)
  ORDER BY icinga_objects.name1;

=cut
    
  	$sql = "SELECT DISTINCT ";
  	$sql .= $provdata->{'prefix'} . "objects.name1 AS hostname, ";
  	$sql .= "coalesce(" . $provdata->{'prefix'} . "objects.name2, '__HOSTCHECK') AS name2, ";
  	$sql .= "coalesce(" . $provdata->{'prefix'} . "hoststatus.last_hard_state, " . $provdata->{'prefix'} . "servicestatus.last_hard_state) AS last_hard_state, ";
  	$sql .= "coalesce(" . $provdata->{'prefix'} . "hoststatus.problem_has_been_acknowledged, " . $provdata->{'prefix'} . "servicestatus.problem_has_been_acknowledged) AS acknowledged, ";
  	$sql .= "coalesce(" . $provdata->{'prefix'} . "hoststatus.output, " . $provdata->{'prefix'} . "servicestatus.output) AS output, ";
  	$sql .= "coalesce(unix_timestamp(" . $provdata->{'prefix'} . "hoststatus.last_check), unix_timestamp(" . $provdata->{'prefix'} . "servicestatus.last_check)) AS last_check, ";
  	$sql .= "unix_timestamp() between unix_timestamp(" . $provdata->{'prefix'} . "scheduleddowntime.scheduled_start_time) AND ";
  	$sql .= "unix_timestamp(" . $provdata->{'prefix'} . "scheduleddowntime.scheduled_end_time) AS downtime ";
  	$sql .= "FROM " . $provdata->{'prefix'} . "objects ";
  	$sql .= "LEFT JOIN " . $provdata->{'prefix'} . "scheduleddowntime ON ";
  	$sql .= $provdata->{'prefix'} . "scheduleddowntime.object_id=" . $provdata->{'prefix'} . "objects.object_id ";
  	$sql .= "LEFT JOIN " . $provdata->{'prefix'} . "hoststatus ON ";
  	$sql .= $provdata->{'prefix'} . "objects.object_id=" . $provdata->{'prefix'} . "hoststatus.host_object_id ";
  	$sql .= "LEFT JOIN " . $provdata->{'prefix'} . "servicestatus ON ";
  	$sql .= $provdata->{'prefix'} . "objects.object_id=" . $provdata->{'prefix'} . "servicestatus.service_object_id ";
  	$sql .= "WHERE " . $provdata->{'prefix'} . "objects.is_active=1 ";
  	$sql .= "AND (" . $provdata->{'prefix'} . "objects.objecttype_id=1 OR ";
  	$sql .= $provdata->{'prefix'} . "objects.objecttype_id=2) ";
  	$sql .= "ORDER BY " . $provdata->{'prefix'} . "objects.name1";
  	
  }else{
    # query data for specified service
    $sql = "SELECT name2 AS service, current_state AS state FROM " . $provdata->{'prefix'} . "objects, " . $provdata->{'prefix'} . "servicestatus ";
    $sql .= "WHERE object_id = service_object_id AND is_active = 1 AND name2 IN (";
    # go trough service_names array
    for (my $i=0;$i<scalar @{ $service_names };$i++){
  	  $sql .= "'" . lc($service_names->[$i]) . "', ";
    }
    # remove trailing ', '
    chop $sql;
    chop $sql;
    $sql .= ") ORDER BY name1";
  }
  
  return $sql;
  
}


#----------------------------------------------------------------

# construct livetstatus query
sub _query_livestatus {
	
  my $self			= shift;
  my $service_names	= shift or die ("Missing service_names!");
  
  my $query = undef;
   
  # get service status for given host and services
  # construct livestatus query
  if ($service_names eq "__all"){
  	$query->[0] = "GET services\n
Columns: host_name description last_hard_state plugin_output last_check acknowledged\n";
    # get host status
    $query->[1] = "GET hosts\n
Columns: name last_hard_state plugin_output last_check acknowledged";
  }else{
  	# query data for specified service
    $query->[0] = "GET services\n
Columns: display_name state\n";
    # go through service array
    for (my $i=0;$i< scalar @{ $service_names };$i++){
   	  $query->[0] .= "Filter: display_name = " . lc($service_names->[$i]) . "\n";
    }
    $query->[0] .= "Or: " . scalar @{ $service_names } . "\n" if scalar @{ $service_names } > 1;
  }
  	  
  return $query;
  
}


#----------------------------------------------------------------

# get service status from IDOutils
sub _get_ido {
	
  my $self		= shift;
  my $provdata 	= shift;
  my $sql		= shift or die ("Missing SQL query!");
  my $fetch		= shift;	# how to handle results
  
  my $result;
  
  my $dsn = undef;
  # database driver
  if ($provdata->{'type'} eq "mysql"){
    use DBI;	  # MySQL
  	$dsn = "DBI:mysql:database=$provdata->{'database'};host=$provdata->{'host'};port=$provdata->{'port'}";
  }elsif ($provdata->{'type'} eq "pgsql"){
	use DBD::Pg;  # PostgreSQL
  	$dsn = "DBI:Pg:dbname=$provdata->{'database'};host=$provdata->{'host'};port=$provdata->{'port'}";
  }else{
  	croak "Unsupported database type: $provdata->{'type'}";
  }
  
  # connect to database
  my $dbh   = eval { DBI->connect_cached($dsn, $provdata->{'username'}, $provdata->{'password'}) };
  if ($DBI::errstr){
  	croak "$DBI::errstr: $@";
  }
  my $query = eval { $dbh->prepare( $sql ) };
  eval { $query->execute };
  if ($DBI::errstr){
  	croak "$DBI::errstr: $@";
  }
  
  # prepare return
  if (! defined $fetch || $fetch eq "all"){
  	# use hashref to fetch results
    $result = $query->fetchall_hashref("service");
  
  # example output:
  # $VAR1 = {
  #        'production-mail-zarafa' => {
  #                                      'service' => 'production-mail-zarafa',
  #                                      'state' => '0'
  #                                    },
  
  }elsif ($fetch eq "row"){
  	# fetch all data and return array
  	while (my $row = $query->fetchrow_hashref()){
  	  
  	  # set last hard state to 2 (critical) if host check is 1 (down)
  	  if ($row->{ 'name2'} eq "__HOSTCHECK"){
  	  	$row->{ 'last_hard_state' } = 2 if $row->{ 'last_hard_state' } != 0;
  	  }
  	  push @{ $result->{ $row->{ 'hostname' } } }, $row;
  
  # example output:
  # $VAR1 = {
  #         'loadbalancer' => [
  #           {
  #             'name2' => 'PING',
  #             'last_hard_state' => '0',
  #             'hostname' => 'loadbalancer',
  #             'output' => ''
  #           },
  #         ]
  #         },
  	}
  	
  }elsif ($fetch eq "program_start"){
  	$result = $query->fetchall_hashref("program_start");
  	
  	# example output:
  	# $VAR1 = {
    #      '1422429147' => {
    #                        'program_start' => 1422429147
    #                      }
    #    };
  	
  }else{
  	croak "Unsupported fetch method: " . $fetch;
  }
  
  
  # disconnect from database
  #$dbh->disconnect;
  
  return $result;
  
}


#----------------------------------------------------------------

# get service status from mk-livestatus
sub _get_livestatus {
	
  my $self		= shift;
  my $provdata	= shift;
  my $query		= shift or croak ("Missing livestatus query!");
  my $fetch		= shift;	# how to handle results
  
  my $result;
  my $ml;
  
  use Monitoring::Livestatus;
  
  # use socket or hostname:port?
  if ($provdata->{ 'socket' }){
    $ml = Monitoring::Livestatus->new( 	'socket' 	=> $provdata->{'socket'},
    									'keepalive' => 1 );
  }else{
    $ml = Monitoring::Livestatus->new( 	'server' 	=> $provdata->{'server'} . ':' . $provdata->{'port'},
    									'keepalive'	=> 1 );
  }
  
  $ml->errors_are_fatal(0);
  
  # prepare return
  if (! defined $fetch || $fetch eq "all"){
  	
    $result = $ml->selectall_hashref($query->[0], "display_name");
    
  # example output:
  # $VAR1 = {
  #        'production-mail-zarafa' => {
  #                                      'service' => 'production-mail-zarafa',
  #                                      'state' => '0'
  #                                    },
  
    foreach my $key (keys %{ $result }){
      # rename columns
      $result->{ $key }{ 'service' } = delete $result->{ $key }{ 'display_name' };
    }
  
  
  }elsif ($fetch eq "row"){
  	# fetch all data and return array
  	my $tmp = undef;
  	for (my $i=0;$i<=@{ $query };$i++){
      push @{ $tmp }, $ml->selectall_arrayref($query->[$i]);
  	}
  	
  	if (! defined $tmp){
  	  my $provdetails = undef;
  	  if ( $provdata->{'socket'} ){
  	  	$provdetails = $provdata->{ 'socket' };
      }else{
    	$provdetails = $provdata->{'server'} . ':' . $provdata->{'port'};
      }
  	  croak "Got empty result from livestatus ($provdetails)";
  	}
    for (my $i=0; $i<scalar @{ $tmp }; $i++ ){
      for (my $j=0; $j<scalar @{ $tmp->[ $i ] }; $j++ ){
        my $tmphash = {};
        # do we deal with host or service checks?
        # host checks don't have description, so array doesn't have last entry
        if (! defined $tmp->[$i][$j][5]){
      	  # host check
      	  $tmphash->{ 'name2' } = "__HOSTCHECK";
      	  $tmphash->{ 'last_hard_state' } = $tmp->[$i][$j][1];
          # set last hard state to 2 (critical) if host check is 1 (down)
      	  $tmphash->{ 'last_hard_state' } = 2 if $tmp->[$i][$j][1] != 0;
          $tmphash->{ 'hostname' } = $tmp->[$i][$j][0];
          $tmphash->{ 'output' } = $tmp->[$i][$j][2];
          $tmphash->{ 'last_check' } = $tmp->[$i][$j][3];
          $tmphash->{ 'acknowledged' } = $tmp->[$i][$j][4];
        }else{
          $tmphash->{ 'name2' } = $tmp->[$i][$j][1];
          $tmphash->{ 'last_hard_state' } = $tmp->[$i][$j][2];
          $tmphash->{ 'hostname' } = $tmp->[$i][$j][0];
          $tmphash->{ 'output' } = $tmp->[$i][$j][3];
          $tmphash->{ 'last_check' } = $tmp->[$i][$j][4];
          $tmphash->{ 'acknowledged' } = $tmp->[$i][$j][5];
        }
  	    push @{ $result->{ $tmp->[$i][$j][0] } }, $tmphash;
      }
 
  # example output:
  # $VAR1 = {
  #         'loadbalancer' => [
  #           {
  #             'name2' => 'PING',
  #             'last_hard_state' => '0',
  #             'hostname' => 'loadbalancer',
  #             'output' => '',
  #             'last_check' => '1424453213'
  #           },
  #         ]
  #         },
  	}

  }elsif ($fetch eq "program_start"){
  	$result = $ml->selectall_hashref($query->[0], "program_start");
  	
  	# example output:
  	# $VAR1 = {
    #      '1422429147' => {
    #                        'program_start' => 1422429147
    #                      }
    #    };
    
  }else{
  	die "Unsupported fetch method: " . $fetch;
  }
  
  if($Monitoring::Livestatus::ErrorCode) {
    croak "Getting Monitoring checkresults failed: $Monitoring::Livestatus::ErrorMessage";
  }
  
  return $result;
  
}


#----------------------------------------------------------------

# get last restart time of monitoring backend
sub _get_restart_time {
	
  my $self			= shift;
  my $provdata		= shift or die ("Missing provdata!");
  
  my $result = undef;
  my $query  = undef;
  
  # prepare queries
  if ($provdata->{ 'provider' } eq "ido"){
    $query  = "SELECT UNIX_TIMESTAMP(program_start_time) AS program_start FROM " . $provdata->{ 'prefix' } . "programstatus ";
    $query .= "ORDER BY instance_id DESC LIMIT 1";
    $result = eval { $self->_get_ido( $provdata, $query, "program_start" ) };
    if ($@){
      carp "Failed to fetch program start time: " . $@;
    }
  }elsif ($provdata->{ 'provider' } eq "mk-livestatus"){
  	$query->[0] = "GET status\n
Columns: program_start\n";
    $result = eval { $self->_get_livestatus( $provdata, $query->[0], "program_start" ) };
    if ($@){
      carp "Failed to fetch program start time: " . $@;
    }
  }else{
  	croak "Unsupported provider: $provdata->{ 'provider' }";
  }
  
  return $result;

}


#----------------------------------------------------------------

# read cached data
sub _open_cache {

  my $self = shift;
#  my $cache_time = shift or die ("Missing cache time!");
  my $cache_file = shift or die ("Missing cache file!");
  
  return 1 unless -f $cache_file;
  
#  # check file age
#  if ( ( time() - $cache_time ) < ( stat( $cache_file )->mtime ) ){
  	
  	# open cache file
    my $yaml = eval { LoadFile( $cache_file ) };
    if ($@){
      carp ("Failed to parse config file $cache_file\n");
      return 1;
    }else{
      return $yaml;
    }
    
#  }
  
  return 1;
  
}


#----------------------------------------------------------------

# write cache
sub _write_cache {

  my $self = shift;
#  my $cache_time = shift or die ("Missing cache time!");
  my $cache_file = shift or die ("Missing cache file!");
  my $data = shift or die ("Missing data to write to cache file!");
  
  my $yaml = Dump ( $data );
  # write into YAML file
  open (CACHE, "> $cache_file") or die ("Can't open file $cache_file for writing: $!");
  print CACHE $yaml;
  close CACHE;
  
}


1;


=head1 EXAMPLES

Get business process status from IDO backend

  use BPView::Data;
  my $dashboard = BPView::Data->new(
  	 views		=> $views,
   	 provider	=> "ido",
   	 provdata	=> $provdata,
  );	
  $json = $dashboard->get_status();
  

Get business process status from IDO backend with all states except ok

  use BPView::Data;
  my $filter = { "state" => "ok" };
  my $dashboard = BPView::Data->new(
  	 views		=> $views,
   	 provider	=> "ido",
   	 provdata	=> $provdata,
   	 filter		=> $filter,
  );	
  $json = $dashboard->get_status
    
    
Get business process details from BPAddon API for business process
production-mail-lb

  use BPView::Data;
  my $details = BPView::Data->new(
  	provider	=> 'bpaddon',
  	provdata	=> $provdata,
  	bp			=> "production-mail-lb",
  );
  $json = $details->get_details();


=head1 SEE ALSO

See BPView::Config for reading and parsing config files.

=head1 AUTHOR

Rene Koch, E<lt>rkoch@rk-it.atE<gt>
Peter Stoeckl, E<lt>p.stoeckl@ovido.atE<gt>

=head1 VERSION

Version 2.000  (May 26 2015))

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by ovido gmbh
          (C) 2014-2015 by BPView development team

This library is free software; you can redistribute it and/or modify
it under the same terms as BPView itself.

=cut
