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


package BPView::Daemon;

BEGIN {
    $VERSION = '1.100'; # Don't forget to set version and release
}

use strict;
use warnings;
use Carp;
use threads;
use Thread::Queue;

# for debugging only
use Data::Dumper;

=head1 NAME

  BPView::Daemon - Functions used by bpviewd daemon

=head1 SYNOPSIS

  use BPView::Daemon;
  my $deaemon = BPView::Daemon->new(
  		log	=> $log,
  	 );
  $daemon->create_status_thread(
  	bp_dir		=> $bp_dir,
	config		=> $config,
	conf		=> $conf,
	cache		=> $cache,
  );

=head1 DESCRIPTION

This module creates threads used by bpviewd.

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an BPView::Daemon object.
See L<EXAMPLES> for more complex variants.

=over 4

=item log

Log4Perl object

=item bp_dir

business process directory

=item config

hash reference of BPView config

=item conf

hash reference of business process config hash

=item cache

Memcached cache object

=item socket

BPView listening socket for client connections

=item bps

Business process data hash reference

=cut


sub new {
  my $invocant	= shift;
  my $class 	= ref($invocant) || $invocant;
  my %options	= @_;
    
  my $self 		= {
  	"bp_dir"		=> undef,	# business process directory
  	"log"			=> undef,	# logging
  	"config"		=> undef,	# BPView configuration hash
  	"conf"			=> undef,	# business process config hash
  	"cache"			=> undef,	# memcached cache object
  	"socket"		=> undef,	# client listening socket
  	"views"			=> undef,	# views (dashboard) hash
  	"bps"			=> undef,	# business process data
  	"mappings"		=> undef,	# service map
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


#----------------------------------------------------------------

=head1 METHODS	

=head2 create_status_thread

 my $status_thread = $daemon->create_status_thread(
	bp_dir		=> $bp_dir,
	config		=> $config,
	conf		=> $conf,
	cache		=> $cache,
);

Create a thread for processing the business process
stati of each view.
Returns thread.

=cut

sub create_status_thread {
	
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
  
  my $log 		= $self->{ 'log' };
  my $bp_dir	= $self->{ 'bp_dir' };
  my $config	= $self->{ 'config' };
  my $conf		= $self->{ 'conf' };
  my $cache		= $self->{ 'cache' };
  my $threads_bp	= $config->{ 'bpviewd' }{ 'threads_bp' };
  
  my $check_status_thread = threads->create({'void' => 1},
	sub {
        while(1)
        {
        	
        	# Sleep first to give fetch thread time to get data from monitoring backend
        	
		# TODO: add new option in config file
		# to make bp processing independent from
		# data fetching!
            $log->info("Sleeping for $config->{ 'bpviewd' }{ 'check_interval' } seconds.");
            sleep($config->{ 'bpviewd' }{ 'check_interval' });
            
        	my $start_time = time();
        	$log->info("Processing business processes.");
        	$log->info("Start time: " . localtime($start_time));
            ## get all config files and iterate
            $log->debug("Getting config files.");
            my @files = <$bp_dir/*.yml>;
            #my $file;

			# get all status data for workers
            my $data = BPView::Data->new(
#            		provider	=> $config->{ 'provider' }{ 'source' },
#            		provdata	=> $config->{ $config->{ 'provider' }{ 'source' } },
					config		=> $config,
					log			=> $log,
            );
			$log->debug("Fetching status data.");
            my $status = eval { $data->get_bpstatus() };
            if ($@) {
            	$log->error("Failed to read status data: $@.");
            	#$service_state = $result{'unknown'};
            }else{
            	$log->debug("Successfully fetched status data.");
            }
            $log->info("Fetching data finished: " . localtime(time()));
            
            # create new threads for parallel processing
            my $queue = Thread::Queue->new();
            my @workers = map {
            	threads->create(
            		sub {
            			# Loop until no more work
            			while (defined (my $file = $queue->dequeue())){
            				# end
            				return unless defined $file;

							$log->debug("Processing file $file.");
				
                			## check if config file is empty (see man perlfunc to get more
                			# informations)
                			if ( -z $file){
                    			$log->error("Config file $file is empty. Will be ignored");
                    			next;
                			}
                			my $bp_name = $file;
                			$bp_name	=~ s/$bp_dir//g;
                			$bp_name	=~ s/\///;
                			$bp_name	=~ s/.yml//;
                			my $service_state = '';
 
 							### TODO: this shouldn't be necessary as config is already in memory
    						$log->debug("Reading config file $file.");
                			my $bpconfig = eval{ $conf->read_config( file => $file ) };
                			if ($@) {
                  				$log->error("Reading configuration files failed: $@");
                 				$bpconfig = '';
                			}else{
                				$log->debug("Successfully read config file.");
                			}
 
                			# process BPs
                			my $bp = BPView::BP->new(
                				log			=> $log,
                				bps			=> $status,
                				bpconfig	=> $bpconfig,
                				config		=> $config,
                				mappings	=> $self->{ 'mappings' },
                			);
                			$log->debug("Processing business processes.");
                			my $status = eval { $bp->get_bpstatus() };
                			if ($@) {
                				$log->error("Processing BPs failed: $@");
                				$result = '';
                			}else{
                				$log->debug("Successfully processed business processes.");
                			}
                			
                			# process BP age
                			$log->debug("Processing business processes age.");
                			my $age = eval { $bp->get_bpage( "bp_name" => $bp_name) };
                			if ($@) {
                				$log->error("Processing BPs age failed: $@");
                				$result = '';
                			}else{
                				$log->debug("Successfully processed business processes age.");
                			}
                			
                			# Updating memcached
                			$log->debug("Updating cache.");
                			$log->debug("Updating BP $bp_name (set business process status code $status)");
                			$log->debug("Updating BP $bp_name (set business process age $age)");
                			$cache->set($bp_name, { "status" => uc( $status ), "age" => $age });
                
            			}
            		}           	
            	)
        	} 1..$threads_bp;
 

		# send files to queue
		$queue->enqueue($_) for @files;
		# no more work
		$queue->enqueue(undef) for 1..$threads_bp;
		# terminate
		$_->join() for @workers;
		
		$log->info("Calculations finished: " . localtime(time()));
           
        }
    }) or croak "Can't create thread!";
    
    # return thread
	return $check_status_thread;

}


#----------------------------------------------------------------

=head1 METHODS	

=head2 create_client_thread

my $client_thread = $daemon->create_client_thread(
	'config'		=> $config,
	'socket'		=> $socket,
	'views'			=> $views,
	'bps'			=> $bps,
	'cache'			=> $cache,
);

Create a thread for handling client connections and
return data to clients via socket.
Returns thread.

=cut

sub create_client_thread {
	
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
  
  my $log 		= $self->{ 'log' };
  my $config	= $self->{ 'config' };
  my $cache		= $self->{ 'cache' };
  my $socket	= $self->{ 'socket' };
  my $views		= $self->{ 'views' };
  my $bps		= $self->{ 'bps' };

  # create thread with no return value
  my $client_thread = threads->create({'void' => 1},
    sub {
        while(1)
        {
            # waiting for a new client connection
            $log->info("Waiting for client connections.");
            my $client_socket = $socket->accept();

            # get information about a newly connected client
            my $client_address = $client_socket->peerhost();
            my $client_port = $client_socket->peerport();
            $log->debug("Connection establised from $client_address:$client_port.");

            # read characters from the connected client
            my $socket_data= "";
            $log->debug("Receiving data from client.");
            $client_socket->recv($socket_data, $config->{ 'bpviewd' }{ 'read_chars' });
            $log->error("Failed to receive data: $!") if $!;

            # expect parameters in json-format
            my $json = JSON::PP->new->pretty;
            $json->utf8('true');
            $log->debug("Decoding data.");
            my $hash = $json->decode($socket_data);
            $log->error("Failed to decode data: $!") if $!;

            my $response = '';
            if ($hash->{'GET'} eq 'businessprocesses'){
            	$log->debug("Client requested business process data.");
                my $filter = {};
                my $filter_hash = $hash->{'FILTER'};
                
                if ( ! exists $filter_hash->{'dashboard'} ) {
                    $log->error("Wrong API-Call. dashboard Filter is missing");
                }
                
                if ( exists $filter_hash->{'state'} ) {
					$filter->{ 'state' } = $filter_hash->{ 'state' };
                } 
                
                if ( exists $filter_hash->{'name'} ) {
					$filter->{ 'name' } = $filter_hash->{ 'name' };
                }
                
                my $dashboard_API = BPView::Data->new(
                     config     => $config,
                     views      => $views->{ $filter_hash->{'dashboard'} }{ 'views' },
#                     provider   => $config->{ 'bpview' }{ 'datasource' },
#                     provdata   => $config->{ 'bpview'}{ $config->{ 'bpview' }{ 'datasource' } },
                     bps        => $bps,
                     filter     => $filter,
                     cache		=> $cache,
                     log        => $log,
       				  mappings	=> $self->{ 'mappings' },
                   );

				$log->debug("Getting business process status.");
                $response = eval { $dashboard_API->get_status() };
                if ($@){
                	$log->error("Failed to get status: $@");
                }
            }
            elsif ($hash->{'GET'} eq 'services'){
            	$log->debug("Client requested service data.");
                my $filter = {};
                my $businessprocess;
                my $filter_hash = $hash->{'FILTER'};
                
                if ( exists $filter_hash->{'businessprocess'} ) {
                    $businessprocess = $filter_hash->{'businessprocess'};
                } else {
                    $log->error("Wrong API-Call. businessprocess Filter is missing");
                }
                
                if ( exists $filter_hash->{'state'} ) {
					$filter->{ 'state' } = $filter_hash->{ 'state' };
                } 
                
                if ( exists $filter_hash->{'name'} ) {
					$filter->{ 'name' } = $filter_hash->{ 'name' };
                }
                
                my $details_API = BPView::Data->new(
                    config      => $config,
                    bp          => $businessprocess,
#                    provider    => $config->{ 'provider' }{ 'source' },
#                    provdata    => $config->{ $config->{ 'provider' }{ 'source' } },
                    bps         => $bps,
                    filter      => $filter,
                    log			=> $log,
       				  mappings	=> $self->{ 'mappings' },
                   );

				$log->debug("Getting business process service stati.");
                $response = eval { $details_API->get_details() };
                if ($@){
                	$log->error("Failed to get status: $@");
                }
            }

            $client_socket->send($response);

            # notify client that response has been sent
            shutdown($client_socket, 1);
        }
        $socket->close();
    }) or croak "Can't create thread!";
    
    # return thread
	return $client_thread;

}


1;


=head1 EXAMPLES

Create a new thread for processing business processes

  use BPView::Daemon:
  my $status_thread = $daemon->create_status_thread(
	bp_dir		=> $bp_dir,
	config		=> $config,
	conf		=> $conf,
	cache		=> $cache,
  );


Create a new thread for handling client connections

  use BPView::Daemon;
  my $client_thread = $daemon->create_client_thread(
	'config'		=> $config,
	'socket'		=> $socket,
	'views'			=> $views,
	'bps'			=> $bps,
	'cache'			=> $cache,
  );


=head1 SEE ALSO

See BPView::Data for processing business processes

=head1 AUTHOR

Rene Koch, E<lt>rkoch@rk-it.atE<gt>

=head1 VERSION

Version 1.100  (April 02 2015))

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015 by BPView development team

This library is free software; you can redistribute it and/or modify
it under the same terms as BPView itself.

=cut
