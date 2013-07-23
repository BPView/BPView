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
    $VERSION = '1.001'; # Don't forget to set version and release
}  						# date in POD below!

use strict;
use warnings;
use YAML::Syck;
use CGI::Carp qw(fatalsToBrowser);
use File::Spec;

# for debugging only
use Data::Dumper;



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
  my $yaml = LoadFile( $self->{ 'file' } );
  
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
Errors are printed out.
Returns 0 or 1 (Config failure).

  my $config = $conf->validate( 'config' => $config);

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
  push @{ $self->{'errors'} }, "src_dir missing!"  unless $config->{'bpview'}{'src_dir'};
  push @{ $self->{'errors'} }, "data_dir missing!" unless $config->{'bpview'}{'data_dir'};
  push @{ $self->{'errors'} }, "site_url missing!" unless $config->{'bpview'}{'site_url'};
  push @{ $self->{'errors'} }, "provider missing!" unless $config->{'provider'}{'source'};
  
  # check if directories exist
  $self->_check_dir( "src_dir", $config->{'bpview'}{'src_dir'} );
  $self->_check_dir( "data_dir", $config->{'bpview'}{'data_dir'} );
  $self->_check_dir( "template", "$config->{'bpview'}{'src_dir'}/$config->{'bpview'}{'template'}" );
  
  # check data backend provider
  $self->_check_provider( "provider", $config->{'provider'}{'source'}, $config->{ $config->{'provider'}{'source'} } );
  # check bpaddon API
  $self->_check_provider( "provider", "bpaddon", $config->{'bpaddon'} ); 
  
  # print errors to webpage
  if ($self->{'errors'}){
  	
   print "<p>";
   print "Configuration validation failed: <br />";
   
   for (my $x=0;$x< scalar @{ $self->{'errors'} };$x++){
     print $self->{'errors'}->[$x] . "<br />";
   }
   
   print "</p>";
   return 1;
   
  }
  
  return 0;
  
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
  
  if (! -d $dir){
   push @{ $self->{'errors'} }, "$conf: $dir - No such directory!";
  }
  
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
    	
    push @{ $self->{'errors'} }, "ido: Missing host!" unless $config->{'host'};
    push @{ $self->{'errors'} }, "ido: Missing database!" unless $config->{'database'};
    push @{ $self->{'errors'} }, "ido: Missing username!" unless $config->{'username'};
    push @{ $self->{'errors'} }, "ido: Missing password!" unless $config->{'password'};
    push @{ $self->{'errors'} }, "ido: Missing prefix!" unless $config->{'prefix'};
      
    # Support PostgreSQL, too!
    push @{ $self->{'errors'} }, "ido: Unsupported database type: $config->{'type'}!" unless ( $config->{'type'} eq "mysql" || $config->{'type'} eq "pgsql" );
     
  }elsif ($provider eq "mk-livestatus"){
   	 
    # mk-livestatus 
    # requires socket or server
    if (! $config->{ $provider }{'socket'} && ! $config->{'server'}){
     	
      push @{ $self->{'errors'} }, "mk-livestatus: Missing server or socket!";
       
    }else{
     	
      if ($config->{'server'}){
        push @{ $self->{'errors'} }, "mk-livestatus: Missing port!" unless $config->{ $provider }{'port'};
      }
       
    }
     
  }elsif ($provider eq "bpaddon"){
   	
   	push @{ $self->{'errors'} }, "bpaddon: Missing cgi_url!" unless $config->{'cgi_url'};
   	push @{ $self->{'errors'} }, "bpaddon: Missing conf!" unless $config->{'conf'};
   	
  }else{
   	
  	# unsupported provider
    push @{ $self->{'errors'} }, "$conf: $provider not supported!";
   	
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
  
  my $conf = BPView::Config->new ( 'directory' => $directory );
  my $views = $conf->read_dir();
  my $dashboards = $conf->get_dashboards( 'config' => $views);


=head1 SEE ALSO

=head1 AUTHOR

Rene Koch, E<lt>r.koch@ovido.atE<gt>

=head1 VERSION

Version 1.001  (July 23 2013))

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by ovido gmbh

This library is free software; you can redistribute it and/or modify
it under the same terms as BPView itself.

=cut
