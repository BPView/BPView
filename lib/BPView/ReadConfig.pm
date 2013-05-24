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

  BPView::ReadConfig - Initialize the config parameter

=head1 SYNOPSIS

  use BPView::ReadConfig;
my $ReadConfig = BPView::ReadConfig->new("FILENAME");

=head1 DESCRIPTION


=head1 METHODS


=cut


package BPView::ReadConfig;
use YAML;

use strict;
use warnings;



my %ParamBPView;

my @yamlFile = YAML::LoadFile('./haha.yml');

for my $rowHr ( @yamlFile ) {
	%ParamBPView = %$rowHr;
}

print $ParamBPView{"rootproperty"} ."\n";

