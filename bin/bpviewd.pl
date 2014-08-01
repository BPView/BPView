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
use YAML::Syck;
use POSIX;
use File::Pid;
use File::Spec;
use Getopt::Long;
#use Log::Log4perl;
use Cache::Memcached;
use threads;
use JSON::PP;

# for debugging only
use Data::Dumper;

my ($lib_path, $cfg_path, $log_path, $pid_path, $daemonName, $dieNow);
my ($logging, $logFile, $pidFile);
BEGIN {
  $lib_path = "/usr/lib64/perl5/vendor_perl";        # path to BPView lib directory
  $cfg_path = "/etc/bpview";                         # path to BPView etc directory
  $log_path = "/var/log/bpview/";                    # log file path
  $pid_path = "/var/run/";							 # path to /run or /var/run
  $daemonName    = "bpviewd";                             # the name of this daemon
  $dieNow        = 0;                                     # used for "infinte loop" construct - allows daemon mode to gracefully exit
  $logging       = 1;                                     # 1= logging is on
  $logFile       = $log_path. $daemonName . ".log";
}

my $pidfile = $pid_path . $daemonName . ".pid";

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
POSIX::setsid() or die "Can't start a new session.";

# write PID file
my $pid_file = File::Pid->new({
				file	=> $pidfile,
});

if (-f $pidfile){
  die "$daemonName already running!\n";
}else{
  $pid_file->write;
}

# callback signal handler for signals.
$SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signalHandler;
$SIG{PIPE} = 'ignore';

# turn on logging
if ($logging) {
	open LOG, ">>$logFile";
	select((select(LOG), $|=1)[0]); # make the log file "hot" - turn off buffering
}

# open config files if not cached
my $conf = BPView::Config->new();

# open config file directory and push configs into hash
my $config = eval{ $conf->read_dir( dir => $cfg_path ) };

my $cache =  new Cache::Memcached {
                 'servers' => [ $config->{ 'bpviewd' }{ 'cache_host' } . ':' . $config->{ 'bpviewd' }{ 'cache_port' }],
                 'compress_threshold' => 10_000,
             };

# validate config
eval { $conf->validate( 'config' => $config ) };

# open config file directory and push configs into hash
my $bps = eval {$conf->read_dir( dir => $cfg_path . "/bp-config" )};

my $views = eval { $conf->read_dir( dir => $cfg_path . "/views" ) };
# replaces possible arrays in views with hashes
$views = eval { $conf->process_views( 'config' => $views ) };


my $data = BPView::Data->new(
     config       => $config,
     views        => $views,
     provider     => $config->{ 'provider' }{ 'source' },
     provdata     => $config->{ $config->{ 'provider' }{ 'source' } },
     bps          => $bps,
     filter       => "",
   );

## Create a working dir on a tmpfs filesystem
#if (-d "/run") {
#        mkdir "/run/bpview" unless -d "/run/bpview";
#}
#elsif (-d "/dev/shm") {
#        mkdir "/dev/shm/bpview" unless -d "/dev/shm/bpview";
#}
#else {
#        logEntry("ERROR: Can't create a bpview directory on a tmpfs filesystem. You need to create a tmpfs at /run or /dev/shm", 1);
#}

my $bp_dir      = $cfg_path . "/bp-config";
my $check_status_thread = threads->create({'void' => 1},
    sub {
        while(1)
        {
            ## get all config files and iterate
            my @files = <$bp_dir/*.yml>;
            foreach $file (@files) {
                ## check if config file is empty
                if ( -z $file){
                    logEntry("ERROR: config file $file is empty. Will be ignored", 0);
                    continue;
                }
                $file =~ s/$bp_dir//g;
                $file =~ s/\///;
                $file =~ s/.yml//;
                my $bp_name = $file;
                my $service_state = '';
    
                ## TODO: extract to own sub functions
                my $data = BPView::Data->new(
                			provider	=> $config->{ 'provider' }{ 'source' },
                			provdata	=> $config->{ $config->{ 'provider' }{ 'source' } },
                         );
                my $status = eval { $data->get_bpstatus() };
                if ($@) {
                  logEntry("ERROR: Failed to read status data.\nReason: $@", 0);
                  $service_state = $result{'unknown'};
                }
    
                my $bpconfig = eval{ $conf->read_config( file => $file ) };
                if ($@) {
                  logEntry("ERROR: Reading configuration files failed.\nReason: $@", 0);
                  $bpconfig = '';
                }
    
                # process BPs
                my $bp = BPView::BP->new(
                		bps			=> $status,
                		bpconfig	=> $bpconfig,
                		);
                my $result = eval { $bp->get_bpstatus() };
                if ($@) {
                  logEntry("ERROR: Processing BPs failed.\nReason: $@", 0);
                  $result = '';
                }
    
                # If value already exists in cache -> update
                # if not -> add
                if($cache->get($bp_name)){
                    $cache->set($bp_name, uc( $result ));
                } else {
                    $cache->add($bp_name, uc( $result ));
                }
            }
            sleep($config->{ 'bpviewd' }{ 'check_interval' });
        }
    }
);


my $counter = 0;
my $repeater = 300/$config->{ 'bpviewd' }{ 'sleep' };

# creating a listening socket
my $socket = new IO::Socket::INET (
    LocalHost => $config->{ 'bpviewd' }{ 'local_host' },
    LocalPort => $config->{ 'bpviewd' }{ 'local_port' },
    Proto => $config->{ 'bpviewd' }{ 'proto' },
    Listen => 5,
    Reuse => 1
);
die "cannot create socket $!\n" unless $socket;

my $hash;

# create thread with no return value
my $socket_thread = threads->create({'void' => 1},
    sub {
        while(1)
        {
            # waiting for a new client connection
            my $client_socket = $socket->accept();

            # get information about a newly connected client
            my $client_address = $client_socket->peerhost();
            my $client_port = $client_socket->peerport();

            # read characters from the connected client
            my $socket_data= "";
            $client_socket->recv($socket_data, $config->{ 'bpviewd' }{ 'read_chars' });

            # expect parameters in json-format
            my $json = JSON::PP->new->pretty;
            $json->utf8('true');
            $hash = $json->decode($socket_data);

            my $response = '';
            if ($hash->{'GET'} eq 'businessprocesses'){
                my $filter = {};
                my $filter_hash = $hash->{'FILTER'};
                
                if ( ! exists $filter_hash->{'dashboard'} ) {
                    logEntry("ERROR: wrong API-Call. dashboard Filter is missing", 0);
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
                   );

                $response = $dashboard_API->get_status();
            }
            elsif ($hash->{'GET'} eq 'services'){
                my $filter = {};
                my $businessprocess;
                my $filter_hash = $hash->{'FILTER'};
                
                if ( exists $filter_hash->{'businessprocess'} ) {
                    $businessprocess = $filter_hash->{'businessprocess'};
                } else {
                    logEntry("ERROR: wrong API-Call. businessprocess Filter is missing", 0);
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

                $response = $details_API->get_details();
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

        eval { $data->query_provider() };

        if ($@) {
                my $msg = $@;
                $msg =~ s/\n//g;
                logEntry("ERROR: " . $msg, 0);
        } else {
                if ($counter == $repeater) {
                        logEntry("Fetched. (Repeated " . $repeater . " times, output every 5 minutes)", 0);
                        $counter = 0;
                }
        }
        
        $counter++;

        sleep($config->{ 'bpviewd' }{ 'sleep' });

}


# add a line to the log file
sub logEntry {
	my ($logText, $code) = @_;
	my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
	my $dateTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
	if ($logging) {
		print LOG "$dateTime $logText\n";
	}
	$dieNow = 1 if ($code == 1);
}

# catch signals and end the program if one is caught.
sub signalHandler {
	$dieNow = 1;    # this will cause the "infinite loop" to exit
}

# do this stuff when exit() is called.
END {
	if ($logging) { close LOG }
	$pid_file->remove if defined $pid_file;
}
