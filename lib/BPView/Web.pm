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

package BPView::Web;

BEGIN {
    $VERSION = '1.100'; # Don't forget to set version and release
}  						# date in POD below!

use strict;
use warnings;
use Template;
use CGI::Carp qw(fatalsToBrowser);

# for debugging only
#use Data::Dumper;


=head1 NAME

  BPView::Web - Create a webpage with Template Toolkit

=head1 SYNOPSIS

  use BPView::Web;
  my $page	= BPView::Web->new(
             src_dir	=> '/var/www/bpview/src',
             data_dir	=> '/var/www/bpview/static'
             );
  $page->display_page( page	=> 'main' );

=head1 DESCRIPTION

This module creates a webpage with Template Toolkit.

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an BPView::Web object. <new> takes at least the src_dir 
and data_dir. Arguments are in key-value pairs.
See L<EXAMPLES> for more complex variants.

=over 4

=item src_dir

path to Template Toolkit src directory

=item data_dir

path to BPView static directory

=item site_url

site url of BPView (default: /bpview)

=item template

name of template to use (default: default)
Make sure to create a folder with this name in:
  $data_dir/css/
  $data_dir/images
  $src_dir/
  
=item page

name of TT template for displaying webpage

=item content

additional content which shall be passed to TT 

=item refresh

refresh interval of webpage (default: 15000) [ms]

=cut


sub new {
	
  my $invocant 	= shift;
  my $class 	= ref($invocant) || $invocant;
  my %options	= @_;
  
  my $self = {
  	"src_dir"			=> undef,		# template toolkit src directory
  	"data_dir"			=> undef,		# static html directory
  	"site_url"			=> "/bpview",	# site url
  	"template"			=> "default",	# template to use
    "css"				=> "bpview",	# CSS file to use
  	"page"				=> "main",		# page to display
  	"content"			=> undef,		# various content to pass to template toolkit (like dashboards)
  	"refresh"			=> 15000,		# refresh interval
  	"site_name"			=> "a universal <b>B</b>usiness <b>P</b>rocess <b>View</b> UI",
  	"round"				=> undef,
  	"uri_dashb"			=> undef,
  	"uri_filter"		=> undef,
  	"styles"			=> undef,		# Array ref of css style sheets
  };
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
  
  # parameter validation
  croak "Missing src_dir!\n"  if (! defined $self->{ 'src_dir' });
  croak "Missing data_dir!\n" if (! defined $self->{ 'data_dir' });
  
  bless $self, $class;
  
  # check if directories exist
  $self->_check_dir( $self->{ 'src_dir' } );
  $self->_check_dir( $self->{ 'data_dir' } );
  
  return $self;
  
}


#----------------------------------------------------------------

=head1 METHODS	

=head2 display_page

 display_Page ( page => 'page_name' )

Creates a new webpage by using argument 'page' as Template Toolkit template name.
The search order of TT template is: src/template_name, src/global.

  $page->display_page( page	=> 'main' );

=cut


sub display_page {
	
  my $self		= shift;
  my %options	= @_;
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
	
  # page to display ( e.g. main )
  my $tt_template	= $self->{ 'src_dir' } . "/global/" . $self->{ 'page' } . ".tt";

  my $tt_vars		= { 
  	'templ' 		=> $self->{ 'template' },
  	'css'			=> $self->{ 'css' },
  	'src_dir'		=> $self->{ 'src_dir' },
  	'data_dir'		=> $self->{ 'data_dir' },
  	'site_url'		=> $self->{ 'site_url' },
  	'sitename'		=> $self->{ 'site_name' },
  	'round'			=> $self->{ 'round' },
  	'uri_dashb'		=> $self->{ 'uri_dashb' },
  	'uri_filter'	=> $self->{ 'uri_filter' },
  };
  
  if (defined $self->{ 'content' }){
  	$tt_vars->{ 'select_content' } = $self->{ 'content' };
  }
  
  # check for given css style sheets
  if (defined $self->{ 'styles' }){
  	$tt_vars->{ 'styles' } = $self->{ 'styles' };
  }else{
  	# use default style sheet
  	$tt_vars->{ 'styles' }->[0] = 'bpview';
  }
  
  if (defined $self->{ 'refresh' }){
  	# set refresh interval in ms
  	$tt_vars->{ 'refresh_interval' } = $self->{ 'refresh' } * 1000;
  }
  
  # create new template
  my $template = Template->new({
  	ABSOLUTE		=> 1,
  	# user template path is included first to be able to overwride global templates
  	INCLUDE_PATH	=> [ $self->{ 'src_dir' } . "/" . $self->{ 'template' },
  						 $self->{ 'src_dir' } . "/global"],
  	PRE_PROCESS		=> 'config',
  });
  
  # display page with template
  $template->process($tt_template, $tt_vars) || croak "Template process failed: " . $template->error();
  
}


#----------------------------------------------------------------

# internal methods
##################

# check if directory exists
sub _check_dir {
	
  my $self	= shift;
  my $dir	= shift or croak ("Missing directory!");
  
  if (! -d $dir){
   push @{ $self->{'errors'} }, "$dir - No such directory!";
  }
  
}

1;


=head1 EXAMPLES

Display main page of BPView with template default.

  use BPView::Web;
  my $src_dir	= "/var/www/bpview/src";
  my $data_dir	= "/var/www/bpview/static";
  my $site_url	= "/bpview";
  my $template	= "default";
  
  my $page = BPView::Web->new(
 	src_dir		=> $src_dir,
 	data_dir	=> $data_dir,
 	site_url	=> $site_url,
 	template	=> $template,
  );
  $page->display_page(
    page		=> "main",
  )
  

=head1 SEE ALSO

See BPView::Config for reading and parsing configuration files.

=head1 AUTHOR

Rene Koch, E<lt>r.koch@ovido.atE<gt>
Peter Stoeckl, E<lt>p.stoeckl@ovido.atE<gt>

=head1 VERSION

Version 1.100  (January 29 2014))

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by ovido gmbh

This library is free software; you can redistribute it and/or modify
it under the same terms as BPView itself.

=cut
