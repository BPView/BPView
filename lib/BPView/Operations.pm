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
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with BPView.
# If not, see <http://www.gnu.org/licenses/>.


package BPView::Operations;

BEGIN {
    $VERSION = '1.300'; # Don't forget to set version and release
}                                                 # date in POD below!

use strict;
use warnings;
use YAML::Syck;
use Carp;
use File::Spec;
use POSIX qw(strftime setsid);
use File::Path qw(make_path remove_tree);

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
                "cfg_path"      => undef,
  				"lock_file"		=> "/tmp/bpview-reload",
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

=head2 generate_config

my $return = generate_config ( 'config' => $config );

Forks and detached a child process which is responsible for:
  - backing up existing business processes and view
  - fetching bp config from CMDB
  - restarting bpviewd and httpd

Returns:
$VAR1 = {
   "status" : 1,
   "message": "Started config reload."
}

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

  my $script = undef;
     $script = $self->{ 'config' }{ 'businessprocess' }{ 'cmdb_exporter' } if defined $self->{ 'config' }{ 'businessprocess' }{ 'cmdb_exporter' };
  
  defined (my $pid = fork) || $self->{ 'log' }->logdie("Failed to fork reload script: $!");
  if ($pid){
  	
    my $return->{ 'status' } = 1;
  	   $return->{ 'message' } = "Started config reload.";
    return $return;
    
    
  }else{
  	
  	# detach child from parent
  	chdir '/' or die "Can't chdir to /: $!";
    close STDIN;
    close STDOUT;
    close STDERR;
    
  	# This code is executed by the child process
  	POSIX::setsid() or die "Can't start a new session: $!\n";
  	
  	# Logging
    $self->{ 'log' } = Log::Log4perl::get_logger("BPViewReload::Log");
    $self->{ 'log' }->info("Starting configuration generation");
  
    # check if reload script is running
    if (-e $self->{ 'lock_file' }){
  	  $self->{ 'log' }->logdie("Reload is already running - aborting");
    }else{
  	  open LOCK_FILE, ">$self->{ 'lock_file' }" || $self->{ 'log' }->logdie("Can't create lock file: $!");
  	  close LOCK_FILE;
  	  $self->{ 'log' }->debug("Created lock file $self->{ 'lock_file' }");
    }

    my $date = strftime "%Y-%m-%d-%H-%M-%S", localtime;
    
    # create backup, delete old data and fetch data from CMDB only if
    # CMDB fetch script is specified
    
    if (defined $script){
    	
      $self->{ 'log' }->info("Creating backup of existing configs");
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
        $self->_restore_die ("", "bp-config", $date);
      }
      if ($script_output ne ""){
        $self->{ 'log' }->info($script_output);
      }

    }else{
    	
      $self->{ 'log' }->info("No CMDB fetch script specified - won't fetch any data, only restart daemons!")
      
    }
    
    # we have to change the service names to configuration options!
    $self->{ 'log' }->info("Restarting services");
    
    # TODO! remove hard coded paths!
    
    if (! `/usr/bin/sudo /sbin/service bpviewd restart`){
      $self->_error_die("Failed to restart bpviewd: $!");
    }
	if (! `/usr/bin/sudo /sbin/service httpd reload`){
	  $self->_error_die("Failed to restart Apache: $!");
	}
	
	$self->{ 'log' }->info("[SUCCESS] Successfully generated new configuration");
	
	# remove backup if fetch script is specified
	if (defined $script){
	  remove_tree("$self->{ 'cfg_path' }/backup/$date");
	}
  
    # remove PID file
    unlink $self->{ 'lock_file' };
    exit 0;

  }
  
}


#----------------------------------------------------------------

# internal methods
##################

sub _error_die {
  my $self		= shift;
  my $error_msg	= shift;
  
  $self->{ 'log' }->error($error_msg);
  unlink $self->{ 'lock_file' };
  exit 0;
}

sub _restore_die {
  my $self		= shift;
  my $error_msg	= shift;
  my $folder	= shift;
  my $date		= shift;
  
  $self->{ 'log' }->error($error_msg) if $error_msg ne "";
  $self->_restore ($folder, $date);
  remove_tree("$self->{ 'cfg_path' }/backup/$date");
  $self->{ 'log' }->error($error_msg) if $error_msg ne "";
  
  unlink $self->{ 'lock_file' };
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
  }else{
  	remove_tree("$self->{ 'cfg_path' }/backup/$date/$folder");
  }
}

sub _status_script {
  my $self		= shift;

  # return 
  my $return;
  if (! -e $self->{ 'lock_file' }){
    $return = $self->_check_last_run();
  }else{
  	$return->{ 'status' } = 1;
  	$return->{ 'message' } = "Reload script is still running.";
  }
  
  return $return;

}


sub _check_last_run {
	# TODO: Remove hardcoded log file path!
  my $status = `tail -1 /var/log/bpview/reload.log`;
  my $return;
  if ($status =~ /\[SUCCESS\]/){
  	$return->{ 'status' }  = 0;
    $return->{ 'message' } = "Sucessfully generated and reloaded configuration!";
  }elsif ($status =~ /\[ERROR\]/){
  	$return->{ 'status' }  = 2;
    $return->{ 'message' } = "Failed to generate and reload configuration! Please check reload.log!";
  }else{
  	$return->{ 'status' }  = 3;
    $return->{ 'message' } = "Unknown status of config generation run!";
  }
  return $return;
}


=head1 EXAMPLES

use BPView::Operations;
        my $operations = BPView::Operations->new(
         config        => $config,
         cfg_path	   => $cfg_path,
);
        $operations->generate_config();
        $operations->_status_script();

=head1 AUTHOR

Peter Stoeckl, E<lt>p.stoeckl@ovido.atE<gt>
Rene Koch, E<lt>rkoch@rk-it.atE<gt>

=head1 VERSION

Version 1.300 (April 02 2015))

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by ovido gmbh
          (C) 2014-2015 by BPView Development Team

This library is free software; you can redistribute it and/or modify
it under the same terms as BPView itself.

=cut



1;
