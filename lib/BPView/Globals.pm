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


package BPView::BPWriter;

BEGIN {
    $VERSION = '1.000'; # Don't forget to set version and release
}  						# date in POD below!

use strict;
use warnings;
use CGI::Carp;
use File::Spec;
use POSIX qw/strftime/;
use Log::Log4perl;

# for debugging only
use Data::Dumper;

=head1 NAME

  BPView::Globals - Global Modules for BPView 

=head1 SYNOPSIS

  use BPView::Data;
  my $global = BPView::Global->new(
  		config	=> undef,
  		file	=> undef,
  	 );
  gen_nicfg( 'bpcfg' => $yaml, 'config' => $config );


=head1 DESCRIPTION

This module reads business processes stored with yml syntax and writes config files for
monitoring services such as Nagios or Icinga and BP-Addon Tools.

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an BPView::BWWriter object.
See L<EXAMPLES> for more complex variants.

=over 4

=item config

The Config hash including the Config from BPView

=item bpcfg

business process related data 


=cut


sub new {
	
  my $invocant 	= shift;
  my $class 	= ref($invocant) || $invocant;
  my %options	= @_;
  
  my $self 		= {
  		config	=> undef,	# config
  		bpcfg	=> undef,	# business process config 
  		time	=> strftime('%A, %d-%b-%Y %H:%M',localtime), ## outputs 17-Dec-2008 10:08
  };

  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
  
  bless $self, $class;
  return $self;
  
}


#----------------------------------------------------------------

=head1 METHODS	

=head2 write_file

 write_file($output_path, $output_cfg, $output)

Check permissions and Write a files.

=cut


sub write_file {
	my $output_path	= shift;
	my $output_cfg	= shift;
	my $output		= shift or croak ("Missing path or name of configfile");
	
	$output_path =~ s/\/$//;

        if (!(-w "$output_path/$output_cfg")) {
            die "Do you have a permission problem? Unable to write to $output_path/$output_cfg";
            return 1;
        }
		else {
			open (OUT, ">$output_path/$output_cfg") or croak "unable to write to $output_path/$output_cfg";
				print OUT $output;
			close(OUT);

			return 0;
		}
}




#----------------------------------------------------------------

# internal methods
##################






1;

#TODO!: Examples BPWwriter.pm

=head1 EXAMPLES

TODO: Examples

=head1 SEE ALSO

=head1 AUTHOR

Peter Stoeckl, E<lt>p.stoeckl@ovido.atE<gt>

=head1 VERSION

Version 1.002  (July 25 2013))

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by ovido gmbh

This library is free software; you can redistribute it and/or modify
it under the same terms as BPView itself.

=cut