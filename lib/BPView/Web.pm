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

use strict;
use warnings;
use Template;
use Carp;
use Data::Dumper;


# create an BPView::Web object
sub new {
  my $class 	= shift;
  my %options	= @_;
  
  my $self = {
  	"src_dir"			=> undef,		# template toolkit src directory
  	"data_dir"			=> undef,		# static html directory
  	"site_url"			=> "/bpview",	# site url
  	"template"			=> "default",	# template to use
  	"page"				=> "main",		# page to display
  	"dashboards"		=> undef,		# dashboards for main page 
  };
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
  
  # parameter validation
  croak "Missing src_dir!\n" if (! defined $self->{ 'src_dir' });
  croak "Missing data_dir!\n" if (! defined $self->{ 'data_dir' });
  
  checkDir( $self->{ 'src_dir' } );
  checkDir( $self->{ 'data_dir' } );
  
  bless $self, $class;
  
  return $self;
  
}


# display web page
sub displayPage {
	
  my $self		= shift;
  my %options	= @_;
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
	
  # page to display ( login | main | detail )
  my $tt_template	= $self->{ 'src_dir' } . "/global/" . $self->{ 'page' } . ".tt";
  my $tt_vars		= { 
  	'templ' 		=> $self->{ 'template' },
  	'src_dir'		=> $self->{ 'src_dir' },
  	'data_dir'		=> $self->{ 'data_dir' },
  	'site_url'		=> $self->{ 'site_url' }, 
  };
  
  if (defined $self->{ 'dashboards' }){
  	$tt_vars->{ 'dashboards' } = $self->{ 'dashboards' };
  }
  
  # create new template
  my $template = Template->new({
  	ABSOLUTE		=> 1,
  	INCLUDE_PATH	=> [$self->{ 'src_dir' } . "/global"],
  	PRE_PROCESS		=> 'config',
  });
  
  # display page with template
  $template->process($tt_template, $tt_vars) || croak "Template process failed: " . $template->error();
  
}


# check if directory exists
sub checkDir {
	
  my $dir = shift;
  
  if (! -d $dir){
  	croak "No such directory: $dir!\n";
  }
  
}



1;