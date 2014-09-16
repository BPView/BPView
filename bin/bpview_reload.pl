#!/usr/bin/perl -w
#
# COPYRIGHT:
#
# This software is Copyright (c) 2013 by ovido, 
#                            (c) 2014 BPView Development Team
#                                     http://github.com/ovido/BPView
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

use Log::Log4perl;

# define default paths required to read config files
my ($lib_path, $cfg_path, $log_path, $reload_log);


#----------------------------------------------------------------
#
# Configuration
#

BEGIN {
  $lib_path = "/usr/lib64/perl5/vendor_perl";   # path to BPView lib directory
  $cfg_path = "/etc/bpview";                    # path to BPView etc directory
  $log_path = "/var/log/bpview/";               # log file path
  $reload_log = $log_path . "reload.log";   	# path to BPView reload log file (default: /var/log/bpview/reload.log)
}

#
# End of configuration block - don't change anything below
# this line!
#
#----------------------------------------------------------------


# load custom Perl modules
use lib "$lib_path";
use BPView::Config;
use BPView::Operations;

# open config files
my $conf = BPView::Config->new();

# open config file directory and push configs into hash
my $config = eval{ $conf->read_dir( dir => $cfg_path ) };
die "Reading configuration files failed.\nReason: $@" if $@;

# initialize Log4perl
my $logconf = "
    log4perl.category.BPViewReload.Log			= INFO, BPViewReloadLog
    log4perl.appender.BPViewReloadLog			= Log::Log4perl::Appender::File
	log4perl.appender.BPViewReloadLog.filename	= $reload_log
    log4perl.appender.BPViewReloadLog.layout	= Log::Log4perl::Layout::PatternLayout
    log4perl.appender.BPViewReloadLog.layout.ConversionPattern = %d %F: [%p] %m%n
";
Log::Log4perl::init( \$logconf );
my $log = Log::Log4perl::get_logger("BPViewReload::Log");


# validate config
eval { $conf->validate( 'config' => $config ) };
$log->error_die($@) if $@;

my $operations = BPView::Operations->new(
   	   config	=> $config,
  	   cfg_path	=> $cfg_path,
   );
   
# loop until config generation has finished
my $param = "reload";
my $status = 1;

while ($status == 1){
	
  my $return = undef;
  
  if ($param eq "reload"){
    $return = eval { $operations->generate_config() };
    $log->info($@) if $@;
  }elsif ($param eq "status"){
    $return = $operations->_status_script();
  }
    
  if (ref($return) ne "HASH"){
    # config generation failed
    $return = undef;
    $status = 0;
    $log->error_die("Another instance is already running!");
  }

  $status = $return->{ 'status' };

}

exit 0;