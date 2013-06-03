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
use Data::Dumper;


# create an empty BPView::Config object
sub new {
  my $class = shift;
  bless [ @_ ], $class;
}
	

sub read {
  my $class = ref $_[0] ? ref shift : shift;
  my $file = shift or croak ("Missing file to read!");
  my %return;
  
  # read and parse YAML config file
#  croak "Read Config: $file" . YAML::Tiny->errstr() if YAML::Tiny->errstr();
  chomp $file;
  $YAML::Syck::ImplicitTyping = 1;
  my $yaml = LoadFile($file);
  
  my @tmp = split /\//, $file;
  $tmp[-1] =~ s/\.yml$//;
  # push into hash with first element name = config file name (without file ending)
  # e.g. bpview.yaml => $conf{'bpview'}
  $return{ $tmp[-1] } = $yaml;
  
  return \%return;
}


sub readdir {
  my $class = ref $_[0] ? ref shift : shift;
  my $dir = shift or croak ("Missing directory to read!");
  
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
  	chomp $file;
    my @tmp = split /\//, $file;
    $tmp[-1] =~ s/\.yml$//;
    # get content of files
    my %ret = %{ BPView::Config->read( $file ) };
    # push into hash with first element name = config file name (without file ending)
    # e.g. bpview.yaml => $conf{'bpview'}
    $conf{ $tmp[-1] } =  $ret{ $tmp[-1] };
  }
  
  closedir (CONFDIR);
  
  return \%conf;
  
}


1;
