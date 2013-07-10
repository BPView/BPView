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


=head1 NAME

  BPView::Config - Initialize the config parameter

=head1 SYNOPSIS

  use BPView::Config;
  my $ReadConfig = BPView::Config->read("FILENAME");

=head1 DESCRIPTION


=head1 METHODS


=cut


package BPView::Config;

use strict;
use warnings;
use YAML::Syck;
use Carp;
use File::Spec;

# for debugging only
use Data::Dumper;


# load custom modules
use lib "../";

use BPView::Config::Livestatus;
use BPView::Config::IDO;


# create an empty BPView::Config object
sub new {
  my $invocant	= shift;
  my $class 	= ref($invocant) || $invocant;
  my $self 		= {
	"verbose"	=> 0,	# enable verbose output
  };
  
  bless $self, $class;
  return $self;
}
	

# read config files
sub read_config {
  my $self = shift;
  my $file = shift or croak ("Missing file to read!");
  my %return;
  
  # read and parse YAML config file
#  croak "Read Config: $file" . YAML::Tiny->errstr() if YAML::Tiny->errstr();
  chomp $file;
  $YAML::Syck::ImplicitTyping = 1;
  my $yaml = LoadFile($file);
  
#  my @tmp = split /\//, $file;
#  $tmp[-1] =~ s/\.yml$//;
#  # push into hash with first element name = config file name (without file ending)
#  # e.g. bpview.yaml => $conf{'bpview'}
#  $return{ $tmp[-1] } = $yaml;
#  
#  return \%return;
  return $yaml;
}


sub read_dir {
  my $self	= shift;
  my $dir	= shift or croak ("Missing directory to read!");
  
  croak ("Read Config: Input parameter $dir isn't a directory!") if ! -d $dir;
  
  my %conf;
  
  # get list of config files
  opendir (CONFDIR, $dir) or croak ("Read Config: Can't open directory $dir: $!");
  
  while (my $file = readdir (CONFDIR)){
  	# use absolute path instead of relative
  	next if $file =~ /\.\./;
  	$file = File::Spec->rel2abs($dir . "/" . $file);
  	# skip directories
  	next if -d $file;
  	next unless $file =~ /\.yml$/;
  	chomp $file;
#    my @tmp = split /\//, $file;
#    $tmp[-1] =~ s/\.yml$//;
    # get content of files
#    my %ret = %{ BPView::Config->read_config( $file ) };
    my $tmp = BPView::Config->read_config( $file );
    # push values into config hash
    foreach my $key (keys %{ $tmp }){
      $conf{ $key } = $tmp->{ $key };
    }
    # push into hash with first element name = config file name (without file ending)
    # e.g. bpview.yaml => $conf{'bpview'}
#    $conf{ $tmp[-1] } =  $ret{ $tmp[-1] };
  }
  
  closedir (CONFDIR);
  
  return \%conf;
  
}


# validate configuration file
sub validate {
  my $self		= shift;
  my $config	= shift or croak ("BPView::Config->validate: Missing config!");
  
  # go through config values
  # parameters given?
  push @{ $self->{'errors'} }, "src_dir missing!"  unless $config->{'bpview'}{'src_dir'};
  push @{ $self->{'errors'} }, "data_dir missing!" unless $config->{'bpview'}{'data_dir'};
  push @{ $self->{'errors'} }, "site_url missing!" unless $config->{'bpview'}{'site_url'};
  push @{ $self->{'errors'} }, "provider missing!" unless $config->{'provider'}{'source'};
  
  # check if directories exist
  $self->_check_dir( "src_dir", $config->{'bpview'}{'src_dir'} );
  $self->_check_dir( "data_dir", $config->{'bpview'}{'data_dir'} );
  $self->_check_dir( "template", "$config->{'bpview'}{'src_dir'}/$config->{'bpview'}{'template'}" );
  $self->_check_provider( "provider", $config->{'provider'}{'source'}, $config->{ $config->{'provider'}{'source'} } );
  
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


sub getDashboards {
	
  my $self 	= shift;
  my $views = shift;
  my $dashboards = [];
  
  # go through view hash
#  foreach my $conffile (keys %{ $views} ){
#  	foreach my $dashboard (keys %{ $views->{ $conffile } }){
#  	  push @{ $dashboards }, $dashboard;
#  	}
  foreach my $dashboard (keys %{ $views }){
   push @{ $dashboards }, $dashboard;
  }
#  }
  
  return $dashboards;
  
}


## old!!!
#sub getProvider {
#	
#  my $self	= shift;
#  my $conf	= shift;
#  my $provider = undef;
#  
#  if (! $conf->{ 'provider' }{ 'source' }){
#  	croak "Provider not found in config!\n";
#  }else{
#  	$provider = $conf->{ 'provider' }{ 'source' };
#  }
#  
#  # verify provider details
#  if (! $conf->{ $provider }){
#  	croak "Provider $provider not found in config!\n";
#  } 
#  
#  if ($provider eq "ido"){
#  	my $ido = BPView::Config::IDO->new( %{ $conf->{ $provider } } );
#  	   $ido->verify();
#  	croak "Validating ido config failed!" unless $? eq 0;
#  }elsif( $provider eq "mk-livestatus"){
#    BPView::Config::Livestatus->verify( %{ $conf->{ $provider } });  	
#    croak "Validating mk-livestatus config failed!" unless $? eq 0;
#  }else{
#  	croak "Unsupported provider $provider\n!";
#  }
#  
#  return $provider;
#  
#}


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


# check for datasource provider
sub _check_provider {
  my $self	= shift;
  my $conf	= shift;
  my $provider	= shift or croak ("Missing provider!");
  my $config	= shift or croak ("Missing config!");
  
  # check provider
  if ($provider ne "ido" && $provider ne "mk-livestatus"){
  	
  	# unsupported provider
    push @{ $self->{'errors'} }, "$conf: $provider not supported!";
    
  }else{
    
    # IDOutils
    if ($provider eq "ido"){
      push @{ $self->{'errors'} }, "ido: Missing host!" unless $config->{'host'};
      push @{ $self->{'errors'} }, "ido: Missing database!" unless $config->{'database'};
      push @{ $self->{'errors'} }, "ido: Missing username!" unless $config->{'username'};
      push @{ $self->{'errors'} }, "ido: Missing password!" unless $config->{'password'};
      push @{ $self->{'errors'} }, "ido: Missing prefix!" unless $config->{'prefix'};
      # Support PostgreSQL, too!
      push @{ $self->{'errors'} }, "ido: Unsupported database type: $config->{'type'}!" unless $config->{'type'} eq "mysql";
     
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
   }
  }
}


1;
