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
    log4perl.category.BPViewd.Log							= INFO, BPViewdLog
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
use BPView::Daemon;


# Code Section
##############

my $daemon = BPView::Daemon->new(
	log		=> $log,
#     config       => $config,
#     views        => $views,
#     provider     => $config->{ 'provider' }{ 'source' },
#     provdata     => $config->{ $config->{ 'provider' }{ 'source' } },
#     bps          => $bps,
#     filter       => "",
   );

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


# Create threads
$log->debug("Creating threads.");


# Business status processing thread
my $status_thread = $daemon->create_status_thread(
	bp_dir		=> $bp_dir,
	config		=> $config,
	conf		=> $conf,
	cache		=> $cache,
);


# Client connection thread

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

# Client connection thread
my $client_thread = $daemon->create_client_thread(
	'config'		=> $config,
	'socket'		=> $socket,
	'views'			=> $views,
	'bps'			=> $bps,
	'cache'			=> $cache,
);


# Verify status of threads and restart it in case one dies
until ($dieNow) {

  if ($status_thread->is_running() != 1){
  	$log->error("Status thread isn't running - restarting it.");
  	$status_thread = $daemon->create_status_thread(
		bp_dir		=> $bp_dir,
		config		=> $config,
		conf		=> $conf,
		cache		=> $cache,
	);
  }
  
  if ($client_thread->is_running() != 1){
  	$log->error("Client thread isn't running - restarting it.");
  	$client_thread = $daemon->create_client_thread(
		'config'		=> $config,
		'socket'		=> $socket,
		'views'			=> $views,
		'bps'			=> $bps,
		'cache'			=> $cache,
	);
  }
  
  sleep (10);

}


my $counter = 0;
my $repeater = 300/$config->{ 'bpviewd' }{ 'sleep' };

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
