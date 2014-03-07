#!/usr/bin/perl -w
#
# COPYRIGHT:
#
# This software is Copyright (c) 2013 by ovido
# <sales@ovido.at>
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
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with BPView.
# If not, see <http://www.gnu.org/licenses/>.


package BPView::Operations;

BEGIN {
    $VERSION = '1.100'; # Don't forget to set version and release
}                                                 # date in POD below!

use strict;
use warnings;
use YAML::Syck;
use Carp;
use File::Spec;
use POSIX qw(strftime);
use File::Pid;
use File::Path qw(make_path);

# for debugging only
#use Data::Dumper;

=head1 NAME

BPView::Operations - Some BPView Operations

=head1 SYNOPSIS

use BPView::Operations;
my $operations = BPView::Operations->new(
         config        => $config,
        );
$operations->import_cmdb();

=head1 DESCRIPTION

This module includes different functions for BPViews.

=cut


sub new {
        my $invocant         = shift;
        my $class         = ref($invocant) || $invocant;
        my %options        = @_;
        my $self                 = {
                "config"        => undef,        # config object (hash)
                "cfg_path"        => undef,
        };
        for my $key (keys %options) {
                if (exists $self->{ $key }) {
                        $self->{ $key } = $options{ $key };
                }
                else {
                croak "Unknown option: $key";
                }
        }
        bless $self, $class;
        return $self;
}

#----------------------------------------------------------------

=head1 METHODS        

=head2 import_cmdb

import_cmdb() ( 'config' => $config )

Execute a import script which is configured at
bpview.yml config file as
scripts:
cmdb:

=cut

sub generate_config {
  my $self		= shift;
  my %options	= @_;
  
  for my $key (keys %options){
    if (exists $self->{ $key }){
      $self->{ $key } = $options{ $key };
    }else{
      croak "Unknown option: $key";
    }
  }

  my $script = $self->{'config'}{'businessprocess'}{'cmdb_exporter'};
  $self->{ 'pid_file' } = "/tmp/bpview_reload.pid";
  
  if (my $pid = fork){
  	
  	# wait for PID from child
  	waitpid ($pid, 0);
  	
  }else{
  	
  	# This code is executed by the child process
  	
  	# Logging
    $self->{ 'log' } = Log::Log4perl::get_logger("BPViewReload::Log");
    $self->{ 'log' }->info("Starting configuration generation");
    $self->{ 'log' }->info("Fetching data from CMDB");
  
    # write PID file
    my $pidfile = File::Pid->new({ file => $self->{ 'pid_file'} });
  
    if (-f $self->{ 'pid_file' }){
  	  $self->{ 'log' }->logdie("Fetch script $script is already running - aborting");
    }else{
  	  $pidfile->write;
    }
    
    $self->{ 'log' }->info("Creating backup of existing configs");
    my $date = strftime "%Y-%m-%d-%H-%M-%S", localtime;
    if (! make_path("$self->{ 'cfg_path' }/backup/$date/views", "$self->{ 'cfg_path' }/backup/$date/bp-config") ){
      $self->_error_die("Creating backup folders failed: $!");
    }

	use File::Copy::Recursive qw(rcopy);
	if (! rcopy("$self->{ 'cfg_path' }/views", "$self->{ 'cfg_path' }/backup/$date/views") ){
	  $self->error_die("Backing up views configs failed: $!");
	}
	if (! rcopy("$self->{ 'cfg_path' }/bp-config", "$self->{ 'cfg_path' }/backup/$date/bp-config") ){
	  $self->error_die("Backing up bp-config configs failed: $!");
	}

    $self->{ 'log' }->info("Deleting old config files");
    if (! unlink glob ($self->{ 'cfg_path' } . "/views/*.yml") ){
      $self->_restore_die("Failed to delete views configs: $!", "views", $date);
    }
    if (! unlink glob ($self->{ 'cfg_path' } . "/bp-config/*.yml") ){
      $self->_restore_die("Failed to delete bp-config configs: $!", "bp-config", $date);
    }

    # run script
    $self->{ 'log' }->info("Executing script $script to fetch data from CMDB");
    my $script_output = `$script`;
    if ($? eq 0){
      $self->{ 'log' }->info("Data successfully fetched from CMDB");
    }else{
      $self->{ 'log' }->error("Fetching data failed from CMDB");
      $self->_restore ("views", $date);
      $self->_restore ("bp-config", $date);
      die;
    }
    if ($script_output ne ""){
      $self->{ 'log' }->info($script_output);
    }
    
    # generate Icinga config
    $self->{ 'log' }->info("Generating Icinga configuration");
    $script_output = `/usr/bin/bpview_cfg_writer.pl`;
    if ($? eq 0){
      $self->{ 'log' }->info("Sucessfully created Icinga configuration");
    }else{
      $self->_error_die("Failed to create Icinga configuration");
    }
    if ($script_output ne ""){
      $self->{ 'log' }->info($script_output);
    }

    # we have to change the service names to configuration options!
    $self->{ 'log' }->info("Restarting services");
    if (! `/usr/bin/sudo /sbin/service icinga reload`){
      $self->_error_die("Failed to reload Icinga: $!");
    }
	if (! `/usr/bin/sudo /sbin/services httpd restart`){
	  $self->_error_die("Failed to restart Apache: $!");
	}
	
	$self->{ 'log' }->info("Sucessfully completed generating new configuration");
  
    # remove PID file
    unlink $self->{ 'pid_file' };

  }
  
  # check if child is running
  $self->_status_script();

}


#----------------------------------------------------------------

# internal methods
##################

sub _error_die {
  my $self		= shift;
  my $error_msg	= shift;
  
  $self->{ 'log' }->error($error_msg);
  unlink $self->{ 'pid_file' };
  die;
}

sub _restore_die {
  my $self		= shift;
  my $error_msg	= shift;
  my $folder	= shift;
  my $date		= shift;
  
  $self->{ 'log' }->error($error_msg);
  $self->_restore ($folder, $date);
  
  unlink $self->{ 'pid_file' };
  die;
}

sub _restore {
  my $self		= shift;
  my $folder	= shift;
  my $date		= shift;
	
  # Restore backup
  $self->{ 'log' }->info("Restoring configs from $folder");
  use File::Copy::Recursive qw(rcopy);
  if (! rcopy("$self->{ 'cfg_path' }/backup/$date/$folder/*", "$self->{ 'cfg_path' }/$folder/") ){
    $self->{ 'log' }->error("Failed to restore backup: $!");
  } 
}

sub _status_script {

  return;

}


=head1 EXAMPLES

use BPView::Operations;
        my $operations = BPView::Operations->new(
         config        => $config,
);
        $operations->import_cmdb();
        $operations->write_cfgs();
        $operations->reload();

=head1 AUTHOR

Peter Stoeckl, E<lt>p.stoeckl@ovido.atE<gt>
Rene Koch, E<lt>rkoch@linuxland.atE<gt>

=head1 VERSION

Version 1.100 (March 06 2014))

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by ovido gmbh

This library is free software; you can redistribute it and/or modify
it under the same terms as BPView itself.

=cut



1;
