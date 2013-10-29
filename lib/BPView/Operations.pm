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


package BPView::Operations;

BEGIN {
    $VERSION = '1.000'; # Don't forget to set version and release
}  						# date in POD below!

use strict;
use warnings;
use YAML::Syck;
use Carp;
use File::Spec;
use POSIX qw(strftime);

# for debugging only
#use Data::Dumper;

=head1 NAME

  BPView::Operations - Some BPView Operations

=head1 SYNOPSIS

  use BPView::Operations;
  my $operations = BPView::Operations->new(
   	   config	=> $config,
	);
  $operations->import_cmdb();

=head1 DESCRIPTION

This module includes different functions for BPViews.

=cut


sub new {
	my $invocant 	= shift;
	my $class 	= ref($invocant) || $invocant;
	my %options	= @_;
	my $self 		= {
		"config"	=> undef,	# config object (hash)
		"cfg_path"	=> undef,
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

sub import_cmdb {
	my $self		= shift;
	my %options 	= @_;
	for my $key (keys %options){
		if (exists $self->{ $key }){
			$self->{ $key } = $options{ $key };
		}else{
			croak "Unknown option: $key";
		}
	}
	my $cmdbscript = $self->{'cfg_path'}{'businessprocess'}{'cmdb_exporter'};
	my $cfg_path = $self->{ 'cfg_path' };

	my $date = strftime "%Y-%m-%d", localtime;
	system("cd $cfg_path/views; for i in `ls`; do /bin/cp \$i ../backup/views/\$i-$date.bak; done; cd $cfg_path/bp-config; for i in `ls`; do /bin/cp \$i ../backup/bp-config/\$i-$date.bak; done;") or croak ("ERROR: Can't import data from CMDB. See logfile for more information.");
	system("/bin/rm -f $cfg_path/views/*.yml;/bin/rm -f $cfg_path/bp-config/*.yml;" . $cmdbscript) or croak ("ERROR: Can't import data from CMDB. See logfile for more information.");
	return;
}

=head1 METHODS	

=head2 write_cfgs

 write_cfgs() ( 'config' => $config )

Execute the script bpview_cfg_writer.pl

=cut

sub write_cfgs {
	my $self		= shift;
	my %options 	= @_;
	for my $key (keys %options){
		if (exists $self->{ $key }){
			$self->{ $key } = $options{ $key };
		}else{
			croak "Unknown option: $key";
		}
	}
	system("/usr/bin/bpview_cfg_writer.pl;") or croak ("ERROR: Can't import data from CMDB. See logfile for more information.");
	return; #/bin/cp /etc/bpview/views/ovido.yml.bak /etc/bpview/views/ovido.yml
}

=head1 METHODS	

=head2 reload

 reload() ( 'config' => $config )

Reload any processes and daemons.

Need to configure SUDO

  apache  ALL=(ALL)       NOPASSWD: /sbin/service icinga reload

=cut

sub reload {
	my $self		= shift;
	my %options 	= @_;
	for my $key (keys %options){
		if (exists $self->{ $key }){
			$self->{ $key } = $options{ $key };
		}else{
			croak "Unknown option: $key";
		}
	}
	
	system("/usr/bin/sudo /sbin/service icinga reload");
	return;
}

=head1 EXAMPLES

    use BPView::Operations;
	my $operations = BPView::Operations->new(
    	   config	=> $config,
         );
	$operations->import_cmdb();
	$operations->write_cfgs();
	$operations->reload();   
    

=head1 AUTHOR

Peter Stoeckl, E<lt>p.stoeckl@ovido.atE<gt>

=head1 VERSION

Version 1.000  (September 12 2013))

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by ovido gmbh

This library is free software; you can redistribute it and/or modify
it under the same terms as BPView itself.

=cut














1;