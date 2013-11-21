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
use YAML::Syck;
use POSIX;
use File::Pid;
use File::Spec;
#use Log::Log4perl;
use Cache::Memcached;
use threads;

# for debugging only
use Data::Dumper;

my ($lib_path, $cfg_path, $log_path, $pid_path, $daemonName, $dieNow);
my ($sleepMainLoop, $logging, $logFile, $pidFile);
BEGIN {
  $lib_path	 = "/usr/lib64/perl5/vendor_perl";        # path to BPView lib directory
  $cfg_path	 = "/etc/bpview";                         # path to BPView etc directory
  $log_path  	 = "/var/log/bpview/";                    # log file path
  $daemonName    = "bpviewd";                             # the name of this daemon
  $dieNow        = 0;                                     # used for "infinte loop" construct - allows daemon mode to gracefully exit
  $sleepMainLoop = 10;                                    # number of seconds to wait between "do something" execution after queue is clear
  $logging       = 1;                                     # 1= logging is on
  $logFile       = $log_path. $daemonName . ".log";
}

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



# "infinite" loop where some useful process happens
until ($dieNow) {

	eval { $data->query_provider() };
	logEntry("ERROR:" . $@, 1)if $@;
	logEntry("Fetched.", 0);
	sleep($sleepMainLoop);

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
}
