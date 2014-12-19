#!/usr/bin/perl -w
#
# COPYRIGHT:
#
# This software is Copyright (c) 2013 by ovido
#                            (c) 2014 BPView Development Team
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

use strict;
use warnings;
use POSIX;
use File::Pid;
use Getopt::Long;
use Log::Log4perl;
use Cache::Memcached;
use threads;
use JSON::PP;

# for debugging only
#use Data::Dumper;

my ($lib_path, $cfg_path, $cfg_files, $log_path, $pid_path, $daemonName, $dieNow);
my ($debug, $logFile, $pidFile);


#----------------------------------------------------------------
#
# Configuration
#

BEGIN {
  $lib_path = "/usr/lib64/perl5/vendor_perl";        # path to BPView lib directory
  $cfg_path = "/etc/bpview";                         # path to BPViewd etc directory
  $cfg_files = "bpviewd.yml datasource.yml";         # bpviewd config files
  $log_path = "/var/log/bpview/";                    # log file path
  $pid_path = "/var/run/";							 # path to /run or /var/run
  $daemonName = "bpviewd";                           # the name of this daemon
  $logFile = $log_path. $daemonName . ".log";		 # logfile (default: /var/log/bpview/bpviewd.log)
}

#
# End of configuration block - don't change anything below
# this line!
#
#----------------------------------------------------------------

BEGIN {
  $dieNow = 0;		# used for "infinte loop" construct - allows daemon mode to gracefully exit
}

my $pidfile = $pid_path . $daemonName . ".pid";

# Logging infomration
my $logconf = "
    log4perl.category.BPViewd.Log							= DEBUG, BPViewdLog
    log4perl.appender.BPViewdLog							= Log::Log4perl::Appender::File
	log4perl.appender.BPViewdLog.filename					= $logFile
    log4perl.appender.BPViewdLog.layout						= Log::Log4perl::Layout::PatternLayout
    log4perl.appender.BPViewdLog.layout.ConversionPattern 	= %d %F: [%p] %m%n
";
Log::Log4perl::init( \$logconf );
my $log = Log::Log4perl::get_logger("BPViewd::Log");

# Starting bpviewd
$log->info("Starting bpviewd.");

# check arguments
Getopt::Long::Configure ("bundling");
GetOptions(
    'p:s'    => \$pidfile,     'pidfile:s'   => \$pidfile,
);

# load custom Perl modules
use lib "$lib_path";
use BPView::Config;
use BPView::Data;
use BPView::BP;


# Code Section
##############

chdir '/';
umask 0;
open STDIN,  '/dev/null'   or die "Can't read /dev/null: $!";
open STDOUT, '>>/dev/null' or die "Can't write to /dev/null: $!";
open STDERR, '>>/dev/null' or die "Can't write to /dev/null: $!";
defined( my $pid = fork ) or die "Can't fork: $!";
exit if $pid;

# dissociate this process from the controlling terminal that started it and stop being part
# of whatever process group this process was a part of.
POSIX::setsid() or $log->error_die("Can't start a new session.");

# write PID file
my $pid_file = File::Pid->new({
				file	=> $pidfile,
});

if (-f $pidfile){
  $log->error_die("$daemonName is already running or PID file exists.");
}else{
  $log->debug("Writing PID file $pidfile.");
  $pid_file->write;
}

# callback signal handler for signals.
$SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signalHandler;
$SIG{PIPE} = 'ignore';

# open config files if not cached
my $conf = BPView::Config->new();

# open config file directory and push configs into hash
my $config = {};
my @cfg_files_arr = split(" ", $cfg_files);
foreach my $cfg_file (@cfg_files_arr){
  $log->info("Opening config files $cfg_path/$cfg_file.");
  my $tmp = eval{ $conf->read_config( file => $cfg_path . "/" . $cfg_file ) };
  foreach my $val (keys %{ $tmp }){
  	$config->{ $val } = $tmp->{ $val };
  }
  if ($@){
	$log->error_die("Failed to read configuration: $@");
  }else{
	$log->debug("Reading main configuration succeeded.");
  }
}

my $cache =  new Cache::Memcached {
                 'servers' => [ $config->{ 'bpviewd' }{ 'cache_host' } . ':' . $config->{ 'bpviewd' }{ 'cache_port' }],
                 'compress_threshold' => 10_000,
             };

# validate config
$log->info("Validating configuration.");
eval { $conf->validate_bpviewd( 'config' => $config ) };
if ($@){
	$log->error_die("Failed to validate config: $@");
}else{
	$log->info("Configuration is valid.");
}

# open config file directory and push configs into hash
$log->info("Opening bp-config config directory.");
my $bps = eval {$conf->read_dir( dir => $cfg_path . "/bp-config" )};
if ($@){
	$log->error_die("Failed to read bp-config: $@");
}else{
	$log->info("Successfully read bp-config.");
}

$log->info("Opening views config directory.");
my $views = eval { $conf->read_dir( dir => $cfg_path . "/views" ) };
if ($@){
	$log->error_die("Failed to read views: $@");
}else{
	$log->info("Successfully read views.");
}

$log->debug("Replacing arrays with hashes.");
# replaces possible arrays in views with hashes
$views = eval { $conf->process_views( 'config' => $views ) };
if ($@){
	$log->error_die("Failed to replace arrays with hashed: $@");
}else{
	$log->debug("Succcessfully replaced arrays with hashes.");
}


my $data = BPView::Data->new(
     config       => $config,
     views        => $views,
     provider     => $config->{ 'provider' }{ 'source' },
     provdata     => $config->{ $config->{ 'provider' }{ 'source' } },
     bps          => $bps,
     filter       => "",
   );

my $bp_dir      = $cfg_path . "/bp-config";
$log->debug("Creating threads.");
my $check_status_thread = threads->create({'void' => 1},
    sub {
        while(1)
        {
            ## get all config files and iterate
            $log->debug("Getting config files.");
            my @files = <$bp_dir/*.yml>;
            my $file;
            foreach $file (@files) {

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
    
                ## TODO: extract to own sub functions
                my $data = BPView::Data->new(
                			provider	=> $config->{ 'provider' }{ 'source' },
                			provdata	=> $config->{ $config->{ 'provider' }{ 'source' } },
                         );
				$log->debug("Fetching status data.");
                my $status = eval { $data->get_bpstatus() };
                if ($@) {
                  $log->error("Failed to read status data: $@.");
                  #$service_state = $result{'unknown'};
                }else{
                	$log->debug("Successfully fetched status data.");
                }
 
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
                		bps			=> $status,
                		bpconfig	=> $bpconfig,
                		);
                $log->debug("Processing business processes.");
                my $result = eval { $bp->get_bpstatus() };
                if ($@) {
                  $log->error("Processing BPs failed: $@");
                  $result = '';
                }else{
                	$log->debug("Successfully processed business processes.");
                }
    
                # If value already exists in cache -> update
                # if not -> add
                $log->debug("Updating cache.");
                if($cache->get($bp_name)){
                    $cache->set($bp_name, uc( $result ));
                } else {
                    $cache->add($bp_name, uc( $result ));
                }
                
            }
		# TODO: add new option in config file
		# to make bp processing independent from
		# data fetching!
            $log->debug("Sleeping for $config->{ 'bpviewd' }{ 'check_interval' } seconds.");
            sleep($config->{ 'bpviewd' }{ 'check_interval' });
        }
    }
);


my $counter = 0;
my $repeater = 300/$config->{ 'bpviewd' }{ 'sleep' };

# creating a listening socket
$log->info("Creating new listinging socket on $config->{ 'bpviewd' }{ 'local_host' }:$config->{ 'bpviewd' }{ 'local_port' }");
my $socket = new IO::Socket::INET (
    LocalHost => $config->{ 'bpviewd' }{ 'local_host' },
    LocalPort => $config->{ 'bpviewd' }{ 'local_port' },
    Proto => $config->{ 'bpviewd' }{ 'proto' },
    Listen => 5,
    Reuse => 1
);
$log->error_dir("Cannot create socket: $!") unless $socket;
$log->info("Successfully created socket.");

my $hash;

# create thread with no return value
my $socket_thread = threads->create({'void' => 1},
    sub {
        while(1)
        {
            # waiting for a new client connection
            $log->debug("Waiting for client connections.");
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
            $hash = $json->decode($socket_data);
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
                     provider   => $config->{ 'bpview' }{ 'datasource' },
                     provdata   => $config->{ 'bpview'}{ $config->{ 'bpview' }{ 'datasource' } },
                     bps        => $bps,
                     filter     => $filter,
                     cache		=> $cache,
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
                    provider    => $config->{ 'provider' }{ 'source' },
                    provdata    => $config->{ $config->{ 'provider' }{ 'source' } },
                    bps         => $bps,
                    filter      => $filter,
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
    }
);

# "infinite" loop where some useful process happens
until ($dieNow) {

	# Fetching data from monitoring backends
	# TODO: Rename sleep option in config file

        eval { $data->query_provider() };

        if ($@) {
                my $msg = $@;
                $msg =~ s/\n//g;
                $log->error($msg);
        } else {
                if ($counter == $repeater) {
                        $log->info("Fetched. (Repeated " . $repeater . " times, output every 5 minutes)");
                        $counter = 0;
                }
        }
        
        $counter++;

        sleep($config->{ 'bpviewd' }{ 'sleep' });

}


# catch signals and end the program if one is caught.
sub signalHandler {
	$dieNow = 1;    # this will cause the "infinite loop" to exit
}

# do this stuff when exit() is called.
END {
	if (defined $pid_file){
		$log->debug("Stopping bpviewd.");
		$log->debug("Removing PID file $pidfile.");
		$pid_file->remove if defined $pid_file;
	}else{
		$log->debug("Stopping bpviewd child.");
	}
}
