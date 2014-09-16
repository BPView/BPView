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


package BPView::BP;

BEGIN {
    $VERSION = '1.010'; # Don't forget to set version and release
}  						# date in POD below!

use strict;
use warnings;
use Carp;

# for debugging only
#use Data::Dumper;


=head1 NAME

  BPView::BP - Process BP stati and return BP details

=head1 SYNOPSIS

  use BPView::BP;
  my $bp = BPView::BP->new(
  		bps			=> $business_processes,
  		bpconfig	=> $bp_config,
  	 );
  $result = $bp->get_bpstatus();

=head1 DESCRIPTION

This module calculates business process stati for Icinga/Nagios
and/or returns details for business processes.

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an BPView::BP object. <new> takes at least the business
process status hash and the business process configuration hash. 
Arguments are in key-value pairs.
See L<EXAMPLES> for more complex variants.

=over 4

=item bps

Business process status hash created with BPView::Data->get_bpstatus.

=item bpconfig

Business process configuration details read with BPView::Config->read_config.

Example configuration file:

"produktion-datacenter-website":
  BP:
    NAME: "Website"
    DESC: undef
    TYPE: and
    DISP: 0
    MIND: 0
  HOSTS:
    loadbalancer:
      "HTTP Check":
    webserver01:
      "HTTP Check"
    webserver02:
      "HTTP Check"

=cut


sub new {
  my $invocant	= shift;
  my $class 	= ref($invocant) || $invocant;
  my %options	= @_;
    
  my $self 		= {
  	"bps"		=> undef,	# business process array
  	"bpconfig"	=> undef,	# business process config
  };
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  die "Unknown option: $key";
  	}
  }
  
  # parameter validation
  die "Missing business process hash!" unless defined $self->{ 'bps' };
  die "Missing business process config!" unless defined $self->{ 'bpconfig' };
  
  bless $self, $class;
  return $self;
}


#----------------------------------------------------------------

=head1 METHODS	

=head2 get_bpstatus

 get_bpstatus ()

Get status of business process by comparing service and host
checks with the given conjunction parameter (and|or|min).
Returns Nagios status code (0|1|2|3).

  my $status = $get_bpstatus();
  
$VAR1 = 0

=cut

sub get_bpstatus {
	
  my $self		= shift;
  my %options 	= @_;
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  die "Unknown option: $key";
  	}
  }

  die "Missing business process hash!" unless defined $self->{ 'bps' };
  die "Missing business process config!" unless defined $self->{ 'bpconfig' };
  
  my $result = undef;
  
  # conjunction type of BP
  foreach my $bp_name (keys %{ $self->{ 'bpconfig' } }){
  	
  	if ( lc( $self->{ 'bpconfig' }{ $bp_name }{ 'BP' }{ 'TYPE' } ) eq "and" ){
  	  # and conjunction
  	  $result = $self->_and( $self->{ 'bpconfig' }{ $bp_name }{ 'HOSTS' } );	
  	}elsif ( lc( $self->{ 'bpconfig' }{ $bp_name }{ 'BP' }{ 'TYPE' } ) eq "or" ){
  	  # or conjunction
  	  $result = $self->_or( $self->{ 'bpconfig' }{ $bp_name }{ 'HOSTS' } );	
  	}elsif ( lc( $self->{ 'bpconfig' }{ $bp_name }{ 'BP' }{ 'TYPE' } ) eq "min" ){
  	  # min conjunction
  	  $result = $self->_min( $self->{ 'bpconfig' }{ $bp_name }{ 'HOSTS' }, $self->{ 'bpconfig' }{ $bp_name }{ 'BP' }{ 'MIND' } );	
  	}else{
  	  # unknown conjunction
  	  die "Unknown conjunction: " . $self->{ 'bpconfig' }{ $bp_name }{ 'BP' }{ 'TYPE' };
  	}
  	
  }
 
  return $result;

}


#----------------------------------------------------------------

# internal methods
##################

# "and" conjunction of states
sub _and {
	
  my $self		= shift;
  my $hosts		= shift or croak ("Missing hosts!");
  
  my $state = 0;
  
  # check services for all given hosts
  foreach my $host (keys %{ $hosts }){
  	
  	foreach my $service (keys %{ $hosts->{ $host } }){

      if (! defined $self->{ 'bps' }{ $host }){
        $state = 3;
        next;
      }

  	  my $size = scalar @{ $self->{ 'bps' }{ $host } };
  	  my $tmp_state = 3;
  	  
  	  # compare services
  	  for (my $i=0;$i<$size;$i++){
  	  	if ($self->{ 'bps' }{ $host }->[ $i ]->{ 'name2' } eq $service ){
          my $lh_state =  $self->{ 'bps' }{ $host }->[ $i ]->{ 'last_hard_state' };
          $state = $lh_state if ( $lh_state == 3 && $state == 0 );
          $state = $lh_state if ( $lh_state >= $state || $state == 3 ) && ($lh_state != 3 && $lh_state > 0);
  	  	  # set state to 98 for hosts down
  	  	  if ($self->{ 'bps' }{ $host }->[ $i ]->{ 'name2' } eq "__HOSTCHECK"){
  	  		$state = 98 if $lh_state != 0;
  	  	  }
  	  	  $tmp_state = $state;
  	  	}
  	  }
  	  
  	  # set state to unknown if state was not found, but don't override warning and critical
  	  $state = 3 if ( ( $tmp_state == 3 ) && ( $state == 0 ) );
  	  
  	}
  }
  
  return $state;
	
}


#----------------------------------------------------------------

# "or" conjunction of states
sub _or {

  my $self		= shift;
  my $hosts		= shift or croak ("Missing hosts!");
  
  my $state = 3;
  
  # check services for all given hosts
  foreach my $host (keys %{ $hosts }){
  	
  	foreach my $service (keys %{ $hosts->{ $host } }){
  	  my $size = scalar @{ $self->{ 'bps' }{ $host } };
  	  
  	  # compare services
  	  for (my $i=0;$i<$size;$i++){
  	  	if ($self->{ 'bps' }{ $host }->[ $i ]->{ 'name2' } eq $service ){
  	  	  $state = $self->{ 'bps' }{ $host }->[ $i ]->{ 'last_hard_state' } if $self->{ 'bps' }{ $host }->[ $i ]->{ 'last_hard_state' } < $state;
  	  	}
  	  }
  	  
  	}
  }
  
  return $state;
	
}


#----------------------------------------------------------------

# "min" conjunction of states
sub _min {

  my $self		= shift;
  my $hosts		= shift or croak ("Missing hosts!");
  my $min		= shift or croak ("Missing min value!");
  
  my $count;
  
  # check services for all given hosts
  foreach my $host (keys %{ $hosts }){
  	
  	foreach my $service (keys %{ $hosts->{ $host } }){
  	  my $size = scalar @{ $self->{ 'bps' }{ $host } };
  	  
  	  # compare services
  	  for (my $i=0;$i<$size;$i++){
  	  	if ($self->{ 'bps' }{ $host }->[ $i ]->{ 'name2' } eq $service ){
  	  	  $count->[ $self->{ 'bps' }{ $host }->[ $i ]->{ 'last_hard_state' } ]++;
  	  	}
  	  }
  	  
  	}
  }
  
  # define ok and warning values for comparison
  $count->[0] = 0 unless defined $count->[0];
  $count->[1] = 0 unless defined $count->[1];
  
  my $state = 3;
  if ( $count->[0] >= $min ){
  	$state = 0;
  }elsif ( $count->[0] + $count->[1] >= $min ){
  	$state = 1;
  }else{
  	$state = 2;
  }
  
  return $state;
	
}


1;


=head1 EXAMPLES

Get status code of given business process.

  use BPView::BP;
  my $bp = BPView::BP->new(
  		bps			=> $business_processes,
  		bpconfig	=> $bp_config,
  	 );
  $result = $bp->get_bpstatus();
  

=head1 SEE ALSO

See BPView::Data for fetching BP data.
See BPView::Config for reading BP configuration files.

=head1 AUTHOR

Rene Koch, E<lt>r.koch@ovido.atE<gt>

=head1 VERSION

Version 1.010  (September 02 2014))

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by ovido gmbh

This library is free software; you can redistribute it and/or modify
it under the same terms as BPView itself.

=cut
