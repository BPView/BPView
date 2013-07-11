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
  my $conf = BPView::Config->new;
  my $config = $conf->read_dir( $cfg_dir );
  $conf->validate($config);

=head1 DESCRIPTION

This module searches, opens and validates BPView-YAML config files.

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an BPView::Config object.

=cut


sub new {
	
  my $invocant	= shift;
  my $class 	= ref($invocant) || $invocant;
  
  my $self 		= {
	"verbose"	=> 0,	# enable verbose output
  };
  
  bless $self, $class;
  return $self;
  
}
	

#----------------------------------------------------------------

=head1 METHODS	

=head2 read_config

 read_config ($file)

Opens a specified file and reads its content into Hashref.
Returns Hashref.

  my $file = 'test.yml';
  my $config = $conf->read_config($file);

$VAR1 = {
          'refresh' => {
                         'interval' => 300
                       }
        };

=cut

sub read_config {
	
  my $self = shift;
  my $file = shift or croak ("Missing file to read!");
  my %return;
  
  # read and parse YAML config file
  chomp $file;
  $YAML::Syck::ImplicitTyping = 1;
  my $yaml = LoadFile($file);
  
  return $yaml;
  
}


#----------------------------------------------------------------

=head2 read_dir

 read_dir ($directory)

Searches for files with ending ".yml" in specified directories and calls read_config to
reads its content into Hash.
Returns Hash.

  my $directory = '/etc/bpview';
  my $config = $conf->read_dir($directory);

$VAR1 = {
          'refresh' => {
                         'interval' => 300
                       }
        };

=cut

sub read_dir {
	
  my $self	= shift;
  my $dir	= shift or croak ("Missing directory to read!");
  
  croak ("Read Config: Input parameter $dir isn't a directory!") if ! -d $dir;
  
  my %conf;
  
  # get list of config files
  opendir (CONFDIR, $dir) or croak ("Read Config: Can't open directory $dir: $!");
  
  while (my $file = readdir (CONFDIR)){
  	
  	next if $file =~ /\.\./;
  	
  	# use absolute path instead of relative
  	$file = File::Spec->rel2abs($dir . "/" . $file);
  	
  	# skip directories and non *.yml files
  	next if -d $file;
  	next unless $file =~ /\.yml$/;
  	chomp $file;
  	
    # get content of files
    my $tmp = BPView::Config->read_config( $file );
    
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

 validate ($config)

Validates a specified config hashref if required parameters for BPView are present.
Errors are printed out.
Returns 0 or 1 (Config failure).

  my $config = $conf->validate($config);

=cut

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


#----------------------------------------------------------------

=head2 get_dashboards

 get_dashboard ($views)

Gets dashboard names out of given view config.
Returns dashboard names arrayref.

  my $dashboards = $conf->get_dashboards($views);

=cut

sub get_dashboards {
	
  my $self 	= shift;
  my $views = shift;
  my $dashboards = [];
  
  # go through view hash
  foreach my $dashboard (keys %{ $views }){
  	
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

=head1 EXAMPLES

Read all config files from a given directory and validate its parameters.

  use BPView::Config;
  my $directory = '/etc/bpview';
  
  my $conf = BPView::Config->new;
  my $config = $conf->read_dir( $directory );
  $conf->validate($config);
  
Read view config files and get dashboard names.

  use BPView::Config;
  my $directory = '/etc/bpview/views';
  
  my $conf = BPView::Config->new;
  my $views = $conf->read_dir( $directory );
  my $dashboards = $conf->get_dashboards($views);


=head1 SEE ALSO

TODO


=head1 AUTHOR

Rene Koch, E<lt>r.koch@ovido.atE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by ovido gmbh

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
