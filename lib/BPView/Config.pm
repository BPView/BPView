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


package BPView::Config;

BEGIN {
    $VERSION = '1.100'; # Don't forget to set version and release
}  						# date in POD below!

use strict;
use warnings;
use YAML::Syck;
use Carp;
use File::Spec;

# for debugging only
#use Data::Dumper;



=head1 NAME

  BPView::Config - Open and validate config files

=head1 SYNOPSIS

  use BPView::Config;
  my $conf = BPView::Config->new( 'dir'	=> $cfg_dir);
  my $config = $conf->read_dir();
  $conf->validate( 'config' => $config);

=head1 DESCRIPTION

This module searches, opens and validates BPView-YAML config files.

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an BPView::Config object. Arguments are in key-value pairs.
See L<EXAMPLES> for more complex variants.

=over 4

=item dir

directory to scan for config files with BPView::Config->read_dir()

=item file

config file to parse with BPView::Config->read_config()

=item config

config to validate by BPView::Config->validate() or to get dashboards
from with BPView::Config->get_dashboards() 

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

=cut


sub new {
	
  my $invocant 	= shift;
  my $class 	= ref($invocant) || $invocant;
  my %options	= @_;
  
  my $self 		= {
  		dir		=> undef,	# directory to search for configs
  		file	=> undef,	# file to read
  		config	=> undef,	# config (for validation)
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

=head2 read_config

 read_config ( 'file' => $file)

Opens a specified file and reads its content into Hashref.
Returns Hashref.

  my $file = 'test.yml';
  my $config = $conf->read_config( 'file' => $file);

$VAR1 = {
          'refresh' => {
                         'interval' => 300
                       }
        };

=cut

sub read_config {
	
  my $self		= shift;
  my %options	= @_;
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
  
  # validation
  croak ("Missing file!") unless defined $self->{ 'file' };
  
  my %return;
  
  # read and parse YAML config file
#  chomp $file;
  $YAML::Syck::ImplicitTyping = 1;
  my $yaml = eval { LoadFile( $self->{ 'file' } ) };
  die ("Failed to parse config file $self->{ 'file' }\n") if $@;
  
  return $yaml;
  
}


#----------------------------------------------------------------

=head2 read_dir

 read_dir ( 'dir' => $directory)

Searches for files with ending ".yml" in specified directories and calls read_config to
reads its content into Hash.
Returns Hash.

  my $directory = '/etc/bpview';
  my $config = $conf->read_dir( 'dir' => $directory);

$VAR1 = {
          'refresh' => {
                         'interval' => 300
                       }
        };

=cut

sub read_dir {
	
  my $self		= shift;
  my %options	= @_;
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
  
  # validation
  croak ("Missing directory!") unless defined $self->{ 'dir' };
  croak ("$self->{ 'dir' } isn't a directory!") if ! -d $self->{ 'dir' };
  
  my %conf;
  
  # get list of config files
  opendir (CONFDIR, $self->{ 'dir' }) or croak ("Can't open directory $self->{ 'dir' }: $!");
  
  while (my $file = readdir (CONFDIR)){
  	
  	next if $file =~ /\.\./;
  	
  	# use absolute path instead of relative
  	$self->{ 'file' } = File::Spec->rel2abs($self->{ 'dir' } . "/" . $file);
  	
  	# skip directories and non *.yml files
  	next if -d $self->{ 'file' };
  	next unless $self->{ 'file' } =~ /\.yml$/;
  	chomp $self->{ 'file' };
  	
    # get content of files
    my $tmp = $self->read_config();
    
    # push values into config hash
    foreach my $key (keys %{ $tmp }){
      $conf{ $key } = $tmp->{ $key };
    }
  }
  
  closedir (CONFDIR);
  
  return \%conf;
  
}


#----------------------------------------------------------------

=head2 validate

 validate ( 'config' => $config)

Validates a specified config hashref if required parameters for BPView are present.
Croaks on error.

  $conf->validate( 'config' => $config);

=cut

sub validate {
	
  my $self		= shift;
  my %options	= @_;
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
  
  # validation
  croak ("Missing config!") unless defined $self->{ 'config' };
  
  # go through config values
  my $config = $self->{ 'config' };
  # parameters given?
  croak "src_dir missing in bpview.yml!"  unless $config->{'bpview'}{'src_dir'};
  croak "data_dir missing in bpview.yml!" unless $config->{'bpview'}{'data_dir'};
  croak "site_url missing in bpview.yml!" unless $config->{'bpview'}{'site_url'};
  croak "provider missing in bpview.yml!" unless $config->{'provider'}{'source'};
  
  # check if directories exist
  $self->_check_dir( "src_dir", $config->{'bpview'}{'src_dir'} );
  $self->_check_dir( "data_dir", $config->{'bpview'}{'data_dir'} );
  $self->_check_dir( "template", "$config->{'bpview'}{'src_dir'}/$config->{'bpview'}{'template'}" );
  
  # check data backend provider
  $self->_check_provider( "provider", $config->{'provider'}{'source'}, $config->{ $config->{'provider'}{'source'} } );
  # check bpaddon API
  $self->_check_provider( "provider", "bpaddon", $config->{'bpaddon'} ); 
  
}


#----------------------------------------------------------------

=head2 process_views

 process_views ( 'config' => $config)

Converts an array into hash if products are configured other then expected and
checks if enviroments, topics and products are defined (empty categories aren't
allowed.)

Expected:
dashboard:
  views:
    environment:
      topic:
        product1:
        product2:

Also possible (will be converted into structure above):        
dashboard:
  views:
    environment:
      topic:
        - product1
        - product2

Returns converted view config.

  $config = $conf->process_views( 'config' => $config);

=cut

sub process_views {
	
  my $self		= shift;
  my %options	= @_;
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
  
  # validation
  croak ("Missing config!") unless defined $self->{ 'config' };
  
  # go through config values
  my $config = $self->{ 'config' };
  
  # go through hash
  foreach my $view ( keys %{ $config }){
  	
  	croak ("Missing 'views' option for view $view") unless ( exists $config->{ $view }{ 'views' } );
  	croak ("Empty view $view") unless ( $config->{ $view }{ 'views' } );
  	
  	foreach my $environment ( keys %{ $config->{ $view }{ 'views' } } ){
  		
  	  croak ("Missing topic in environment $environment ($view)") unless ( $config->{ $view }{ 'views' }{ $environment });
  	  
  	  foreach my $topic ( keys %{ $config->{ $view }{ 'views' }{ $environment } }){
  	  	
  	    croak ("Missing product in topic $topic ($view -> $environment)") unless ( $config->{ $view }{ 'views' }{ $environment }{ $topic });
  	    
  	    if (ref ($config->{$view}{'views'}{$environment}{$topic}) eq "ARRAY"){
  	    	
  	      my %tmp;
  	      for (my $i=0;$i<scalar (@{ $config->{ $view }{ 'views' }{ $environment }{ $topic } });$i++){
  	      
  	      	$tmp { $config->{ $view }{ 'views' }{ $environment }{ $topic }->[ $i ] } = undef;
  	      
  	      }
  	      
  	      # replace array with tmp hash values
  	      undef $config->{ $view }{ 'views' }{ $environment }{ $topic };
  	      foreach my $key ( keys %tmp ){
  	      
  	        $config->{ $view }{ 'views' }{ $environment }{ $topic }{ $key } = $tmp{ $key };
  	      
  	      }
  	    }
  	  	
  	  }
  		
  	}
  	
  }
  
  return $config;
  
}


#----------------------------------------------------------------

=head2 get_dashboards

 get_dashboard ( 'config' => $views)

Gets dashboard names out of given view config.
Returns dashboard names arrayref.

  my $dashboards = $conf->get_dashboards( 'config' => $views);

=cut

sub get_dashboards {
	
  my $self		= shift;
  my %options	= @_;
  
  for my $key (keys %options){
  	if (exists $self->{ $key }){
  	  $self->{ $key } = $options{ $key };
  	}else{
  	  croak "Unknown option: $key";
  	}
  }
  
  # validation
  croak ("Missing dashboards!") unless defined $self->{ 'config' };
  
  my $dashboards = [];
  
  # go through view hash
  foreach my $dashboard (keys %{ $self->{ 'config' } }){
  	
   push @{ $dashboards }, $dashboard;
   
  }
  
  return $dashboards;
  
}


#----------------------------------------------------------------

# internal methods
##################

# check if directory exists
sub _check_dir {
	
  my $self	= shift;
  my $conf	= shift;
  my $dir	= shift or croak ("_check_dir: Missing directory!");
  
  croak "$conf: Directory $dir does not exist!" unless -d $dir;
  
}


#----------------------------------------------------------------

# check for datasource provider
sub _check_provider {
	
  my $self	= shift;
  my $conf	= shift;
  my $provider	= shift or croak ("Missing provider!");
  my $config	= shift or croak ("Missing config!");
  
  # IDOutils
  if ($provider eq "ido"){
    	
    croak "ido: Missing host!" unless $config->{'host'};
    croak "ido: Missing database!" unless $config->{'database'};
    croak "ido: Missing username!" unless $config->{'username'};
    croak "ido: Missing password!" unless $config->{'password'};
    croak "ido: Missing prefix!" unless $config->{'prefix'};
      
    # Supported databases are mysql and pgsql
    croak "ido: Unsupported database type: $config->{'type'}!" unless ( $config->{'type'} eq "mysql" || $config->{'type'} eq "pgsql" );
     
  }elsif ($provider eq "mk-livestatus"){
   	 
    # mk-livestatus 
    # requires socket or server
    if (! $config->{ $provider }{'socket'} && ! $config->{'server'}){
     	
      croak "mk-livestatus: Missing server or socket!";
       
    }else{
     	
      if ($config->{'server'}){
        croak "mk-livestatus: Missing port!" unless $config->{'port'};
      }
       
    }
     
  }elsif ($provider eq "bpaddon"){
   	
   	croak "bpaddon: Missing cgi_url!" unless $config->{'cgi_url'};
   	croak "bpaddon: Missing conf!" unless $config->{'conf'};
   	
  }else{
   	
  	# unsupported provider
    croak "$conf: $provider not supported!";
   	
  }
   
}


1;


=head1 EXAMPLES

Read all config files from a given directory and validate its parameters.

  use BPView::Config;
  my $directory = '/etc/bpview';
  
  my $conf = BPView::Config->new( 'directory' => $directory ));
  my $config = $conf->read_dir();
  $conf->validate( 'config' => $config);
  
Read view config files and get dashboard names.

  use BPView::Config;
  my $directory = '/etc/bpview/views';
  
  my $conf = BPView::Config->new ( 'dir' => $directory );
  my $views = $conf->read_dir();
     $views = $conf->process_views( 'config' => $views );
  my $dashboards = $conf->get_dashboards( 'config' => $views );


=head1 SEE ALSO

=head1 AUTHOR

Rene Koch, E<lt>r.koch@ovido.atE<gt>

=head1 VERSION

Version 1.100  (Aug 14 2013))

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by ovido gmbh

This library is free software; you can redistribute it and/or modify
it under the same terms as BPView itself.

=cut
