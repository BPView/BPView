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
use File::Spec;
use Log::Log4perl;

# for debugging only
#use Data::Dumper;

# define default paths required to read config files
my ($lib_path, $cfg_path, $dir);
BEGIN {
  $lib_path = "/usr/lib64/perl5/vendor_perl";   # path to BPView lib directory
  $cfg_path = "/etc/bpview";                    # path to BPView etc directory
  $dir          = $cfg_path . "/bp-config";
}

use lib "$lib_path";
use BPView::Config;
use BPView::BPWriter;

# open config files if not cached
my $conf = BPView::Config->new();

# open config file directory and push configs into hash
my $config = eval{ $conf->read_dir( dir => $cfg_path ) };
die "Reading configuration files failed.\nReason: $@" if $@;

# initialize Log4perl
my $logconf = "
    log4perl.category.BPView.Log		= WARN, Logfile
    log4perl.appender.Logfile			= Log::Log4perl::Appender::File
	log4perl.appender.Logfile.filename	= $config->{ 'logging' }{ 'logfile' }
    log4perl.appender.Logfile.layout	= Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern = %d %F: [%p] %m%n
";
Log::Log4perl::init( \$logconf );
my $log = Log::Log4perl::get_logger("BPView::Log");

# validate config
eval { $conf->validate( 'config' => $config ) };
$log->error_die($@) if $@;

# open config file directory and push configs into hash
my $yaml = eval {$conf->read_dir( dir => $dir )};
$log->error_die($@) if $@;

eval {$conf->validate_bpconfig( 'config' => $yaml )};
$log->error_die($@) if $@;

my $gencfg = BPView::BPWriter->new();

if ($config->{'businessprocess'}{'provider'} eq "bp-addon") {
# not longer needed (pst)
#	eval {$gencfg->gen_bpaddoncfg( 'bpcfg' => $yaml, 'config' => $config )};
#	$log->error_die($@) if $@;

	eval {$gencfg->gen_nicfg( 'bpcfg' => $yaml, 'config' => $config )};
	$log->error_die($@) if $@;	
}
elsif ($config->{'businessprocess'}{'provider'} eq "bp-view") {
	#TODO: some other BP provider
}
else {
	$log->error_die("No business process provider defined!");
}








exit 0;