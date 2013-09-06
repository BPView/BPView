#    Nagios Business Process View and Nagios Business Process Analysis
#    Copyright (C) 2003-2010 Sparda-Datenverarbeitung eG, Nuernberg, Germany
#    Bernd Stroessreuther <berny1@users.sourceforge.net>
#
#    Copyright (c) 2013 by ovido, <sales@ovido.at>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; version 2 of the License.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


package BPView::BP-Addon::ndodb;

use Exporter;
use strict;
use DBI;
use IO::Socket;
use LWP::UserAgent;
use JSON::XS;
#use Data::Dumper;
use Fcntl qw(:DEFAULT :flock);
use lib ('/usr/lib64/nagios-business-process-addon');
#use bsutils;
our @ISA = qw(Exporter);
our @EXPORT = qw(getStates getLastUpdateServiceStatus getDbParam);

my ($dbh, %dbparam, $sql, $sth, @fields, %hardstates, %statusinfos, $hostdirname, $servicedirname, $parentdirname, $servicelist, $in, $line, $servicename, $hostname, $lasthardstate, $currentstate, $output, $lastservicecheck, @lastservicecheck_local, $rc, $jsonref, $subhash);

##############################################################
##############################################################

my $dbConfigFile = "/etc/bpview/bp-addon.cfg";

##############################################################
##############################################################

my @services_state=("OK", "WARNING", "CRITICAL", "UNKNOWN");
my @host_state=("OK", "CRITICAL", "UNKNOWN");


sub getStates()
{
	my %dbparam = &getDbParam();
	my $socket;
	#print STDERR "DEBUG: num of hardstates " . scalar %hardstates . "\n";
	#print STDERR "DEBUG: num of statusinfos " . scalar %statusinfos . "\n";
	if ($dbparam{'cache_time'} > 0)
	{
		#checkCache();
		#print STDERR "DEBUG: num of hardstates " . scalar %hardstates . "\n";
		#print STDERR "DEBUG: num of statusinfos " . scalar %statusinfos . "\n";
		if (scalar %hardstates ne "0")
		{
			#print STDERR "DEBUG: using from cache\n";
			return(\%hardstates, \%statusinfos);
		}
	}
	#print STDERR "DEBUG: fetching info from storage backend\n";
	#print "DEBUG1: ndo=\"$dbparam{'ndo'}\"\n";
	if ($dbparam{'ndo'} eq "db")
	{
		#print "DEBUG2: ndo=db\n";
	        my $db_prefix = $dbparam{'ndodb_prefix'};

	        $dbh = DBI->connect("DBI:mysql:$dbparam{'ndodb_database'}:$dbparam{'ndodb_host'}:$dbparam{'ndodb_port'}", $dbparam{'ndodb_username'}, $dbparam{'ndodb_password'});
	        die "Error: $DBI::errstr\n" unless $dbh;

	        #$sql = "select host_name,service_description,last_hard_state,plugin_output from servicestatus";
	        #$sql = "select ${db_prefix}objects.name1,${db_prefix}objects.name2,${db_prefix}servicestatus.current_state,${db_prefix}servicestatus.output from ${db_prefix}objects,${db_prefix}servicestatus where ${db_prefix}objects.objecttype_id=2 and ${db_prefix}objects.is_active=1 and ${db_prefix}objects.object_id=${db_prefix}servicestatus.service_object_id";
	        $sql = "select ${db_prefix}objects.name1,${db_prefix}objects.name2,${db_prefix}servicestatus.last_hard_state,${db_prefix}servicestatus.output from ${db_prefix}objects,${db_prefix}servicestatus where ${db_prefix}objects.objecttype_id=2 and ${db_prefix}objects.is_active=1 and ${db_prefix}objects.object_id=${db_prefix}servicestatus.service_object_id";

		#print STDERR "$sql\n";
	        $sth = $dbh->prepare($sql);
	        die "Error: $DBI::errstr\n" if $DBI::err;

	        $sth->execute();
	        die "Error: $DBI::errstr\n" if $DBI::err;

	        while (@fields = $sth->fetchrow_array())
	        {
	                #print join("\t", @fields), "\n";
	                $hardstates{"$fields[0];$fields[1]"} = $services_state[$fields[2]] || "UNKNOWN";
	                $statusinfos{"$fields[0];$fields[1]"} = $fields[3];
	        }

	        #$sql = "select host_name,host_status,plugin_output from hoststatus";
	        $sql = "select ${db_prefix}objects.name1,${db_prefix}hoststatus.current_state,${db_prefix}hoststatus.output from ${db_prefix}objects,${db_prefix}hoststatus where ${db_prefix}objects.objecttype_id=1 and ${db_prefix}objects.is_active=1 and ${db_prefix}objects.object_id=${db_prefix}hoststatus.host_object_id";
	        #$sql = "select ${db_prefix}objects.name1,${db_prefix}hoststatus.last_hard_state,${db_prefix}hoststatus.output from ${db_prefix}objects,${db_prefix}hoststatus where ${db_prefix}objects.objecttype_id=1 and ${db_prefix}objects.is_active=1 and ${db_prefix}objects.object_id=${db_prefix}hoststatus.host_object_id";

	        $sth = $dbh->prepare($sql);
	        die "Error: $DBI::errstr\n" if $DBI::err;

	        $sth->execute();
	        die "Error: $DBI::errstr\n" if $DBI::err;

	        while (@fields = $sth->fetchrow_array())
	        {
	                #print join("\t", @fields), "\n";
	                $hardstates{"$fields[0];Hoststatus"} = $host_state[$fields[1]] || "UNKNOWN";
	                $statusinfos{"$fields[0];Hoststatus"} = $fields[2];
	        }

	        $sth->finish();
	        $dbh->disconnect();
	}
	elsif ($dbparam{'ndo'} eq "fs")
	{
		#print "DEBUG2: ndo=fs\n";
		#print "DEBUG: basedir:  $dbparam{'ndofs_basedir'}\n";
		#print "DEBUG: instance: $dbparam{'ndofs_instance_name'}\n\n";

		$servicelist = $dbparam{'ndofs_basedir'} . "/VOLATILE/"  . $dbparam{'ndofs_instance_name'} . "/VIEWS/SERVICELIST";
		$parentdirname="$dbparam{'ndofs_basedir'}/VOLATILE/$dbparam{'ndofs_instance_name'}/HOSTS";

		open (LIST, "<$servicelist") or die "unable to read from file $servicelist\n";
		flock(LIST, LOCK_SH);

		while ($line = <LIST>)
		{
			chomp($line);
			# print "DEBUG: servicelist: $in\n";
			# DEBUG: servicelist:    "internetconnection":[
			# DEBUG: servicelist:       "Provider 1",
			# DEBUG: servicelist:       "Provider 2"
			# DEBUG: servicelist:    ],
			if ($line =~ m/"(.+)":\[/)
			{
				$hostname = cleanup_for_ndo2fs($1);
				#print "DEBUG: hostname:    $hostname\n";
				getStatusFromFS($hostname);
			}
			if ($line =~ m/"(.+)",?\s*$/)
			{
				$servicename = cleanup_for_ndo2fs($1);
				#print "DEBUG: servicename: $hostname:$servicename\n";
				getStatusFromFS($hostname, $servicename);
			}
		}
		close(LIST);
	}
	elsif ($dbparam{'ndo'} eq "merlin")
	{
		#print "DEBUG2: ndo=db\n";
	        my $db_prefix = $dbparam{'ndodb_prefix'};

	        $dbh = DBI->connect("DBI:mysql:$dbparam{'ndodb_database'}:$dbparam{'ndodb_host'}:$dbparam{'ndodb_port'}", $dbparam{'ndodb_username'}, $dbparam{'ndodb_password'});
	        die "Error: $DBI::errstr\n" unless $dbh;

	        #$sql = "select host_name,service_description,last_hard_state,plugin_output from servicestatus";
	        #$sql = "select ${db_prefix}objects.name1,${db_prefix}objects.name2,${db_prefix}servicestatus.last_hard_state,${db_prefix}servicestatus.output from ${db_prefix}objects,${db_prefix}servicestatus where ${db_prefix}objects.objecttype_id=2 and ${db_prefix}objects.is_active=1 and ${db_prefix}objects.object_id=${db_prefix}servicestatus.service_object_id";
	        $sql = "select host_name,service_description,last_hard_state,output from service";

		#print STDERR "$sql\n";
	        $sth = $dbh->prepare($sql);
	        die "Error: $DBI::errstr\n" if $DBI::err;

	        $sth->execute();
	        die "Error: $DBI::errstr\n" if $DBI::err;

	        while (@fields = $sth->fetchrow_array())
	        {
	                #print join("\t", @fields), "\n";
	                $hardstates{"$fields[0];$fields[1]"} = $services_state[$fields[2]] || "UNKNOWN";
	                $statusinfos{"$fields[0];$fields[1]"} = $fields[3];
	        }

	        #$sql = "select host_name,host_status,plugin_output from hoststatus";
	        #$sql = "select ${db_prefix}objects.name1,${db_prefix}hoststatus.current_state,${db_prefix}hoststatus.output from ${db_prefix}objects,${db_prefix}hoststatus where ${db_prefix}objects.objecttype_id=1 and ${db_prefix}objects.is_active=1 and ${db_prefix}objects.object_id=${db_prefix}hoststatus.host_object_id";
	        #$sql = "select host_name,last_hard_state,output from host";
	        $sql = "select host_name,current_state,output from host";

	        $sth = $dbh->prepare($sql);
	        die "Error: $DBI::errstr\n" if $DBI::err;

	        $sth->execute();
	        die "Error: $DBI::errstr\n" if $DBI::err;

	        while (@fields = $sth->fetchrow_array())
	        {
	                #print join("\t", @fields), "\n";
	                $hardstates{"$fields[0];Hoststatus"} = $host_state[$fields[1]] || "UNKNOWN";
	                $statusinfos{"$fields[0];Hoststatus"} = $fields[2];
	        }

	        $sth->finish();
	        $dbh->disconnect();
	}
	elsif ($dbparam{'ndo'} eq "mk_livestatus")
	{
		$socket = IO::Socket::UNIX->new ("Peer" => $dbparam{'ndo_livestatus_socket'}, "Type" => SOCK_STREAM, "Timeout" => 15) or die "unable to connect to unix socket \"" . $dbparam{'ndo_livestatus_socket'} . "\": $!\n";

		print $socket "GET services\n";
		print $socket "Columns: host_name description last_hard_state plugin_output\n\n";

		while ($in = <$socket>)
		{
			chomp($in);
			#print STDERR "DEBUG: $in\n";

			@fields = split(/;/, $in);
	                $hardstates{"$fields[0];$fields[1]"} = $services_state[$fields[2]] || "UNKNOWN";
	                $statusinfos{"$fields[0];$fields[1]"} = $fields[3];
		}

		$socket = IO::Socket::UNIX->new ("Peer" => $dbparam{'ndo_livestatus_socket'}, "Type" => SOCK_STREAM, "Timeout" => 15) or die "unable to connect to unix socket \"" . $dbparam{'ndo_livestatus_socket'} . "\": $!\n";

		print $socket "GET hosts\n";
		print $socket "Columns: name state plugin_output\n\n";

		while ($in = <$socket>)
		{
			chomp($in);
			#print STDERR "DEBUG: $in\n";

			@fields = split(/;/, $in);
	                $hardstates{"$fields[0];Hoststatus"} = $host_state[$fields[1]] || "UNKNOWN";
	                $statusinfos{"$fields[0];Hoststatus"} = $fields[2];
		}
	}
	elsif ($dbparam{'ndo'} eq "icinga-web")
	{
		#print "DEBUG2: ndo=icinga-web\n";
		my $maxConnectionTime = 10;
		#print STDERR "URL prefix: " . $dbparam{'ndo_icinga_web_url_prefix'} . "\n";
		if(substr($dbparam{'ndo_icinga_web_url_prefix'}, -1) eq "/")
		{
			$dbparam{'ndo_icinga_web_url_prefix'} = substr($dbparam{'ndo_icinga_web_url_prefix'}, 0, length($dbparam{'ndo_icinga_web_url_prefix'}) -1);
		}
		#print STDERR "URL prefix: " . $dbparam{'ndo_icinga_web_url_prefix'} . "\n";
	        my $services_url = $dbparam{'ndo_icinga_web_url_prefix'} . "/web/api/service/columns%5BSERVICE_NAME%7CHOST_NAME%7CSERVICE_LAST_HARD_STATE%7CSERVICE_OUTPUT%5D/authkey=" . $dbparam{'ndo_icinga_web_auth_key'} . "/json";
	        my $hosts_url = $dbparam{'ndo_icinga_web_url_prefix'} . "/web/api/host/columns%5BHOST_NAME%7CHOST_CURRENT_STATE%7CHOST_OUTPUT%5D/authkey=" . $dbparam{'ndo_icinga_web_auth_key'} . "/json";
		my ($ua, $request, $result, $content);

		#print STDERR "URL: $services_url\n";
		$ua = new LWP::UserAgent ( 'timeout' => $maxConnectionTime );
		$request = new HTTP::Request ('GET' => "$services_url");
		$result = $ua->request($request);
		#print STDERR "Response Services: " . $result->code() . " " . $result->message() . "\n";

		if ($result->code() >= 400)
		{
			die "Error when requesting service information from icinga API, response code: " . $result->code() . ", message: " . $result->message() . "\n";
		}

		$content = $result->decoded_content();
		$content =~ s/\r\n/\n/g;
		#print STDERR "Content: $content\n";

		$jsonref = decode_json($content);

		#print "DEBUG: $jsonref\n";
		#print "DEBUG: " . Dumper($jsonref) . "\n";
		#print "DEBUG ref: " . ref($jsonref) . "\n";
		if (ref($jsonref) eq "HASH" && defined $jsonref->{'error'})
		{
			die "Error when requesting service information from icinga API, message: $jsonref->{'error'}->[0]->{'message'}\nerrors: $jsonref->{'error'}->[0]->{'errors'}->[0]\n";
		}

		foreach $subhash (@$jsonref)
		{
			#print "\nDEBUG subhash: $subhash\n";
			#print "DEBUG service: $subhash->{'HOST_NAME'};$subhash->{'SERVICE_NAME'} = $services_state[$subhash->{'SERVICE_LAST_HARD_STATE'}]\n";
			#SERVICE_LAST_HARD_STATE
            		#SERVICE_NAME
            		#HOST_NAME
	        	$hardstates{"$subhash->{'HOST_NAME'};$subhash->{'SERVICE_NAME'}"} = $services_state[$subhash->{'SERVICE_LAST_HARD_STATE'}] || "UNKNOWN";
	        	$statusinfos{"$subhash->{'HOST_NAME'};$subhash->{'SERVICE_NAME'}"} = $subhash->{'SERVICE_OUTPUT'}
		}


		#print STDERR "URL: $hosts_url\n";
		$request = new HTTP::Request ('GET' => "$hosts_url");
		$result = $ua->request($request);
		#print STDERR "Response Hosts: " . $result->code() . " " . $result->message() . "\n";

		if ($result->code() >= 400)
		{
			die "Error when requesting host information from icinga API, response code: " . $result->code() . ", message: " . $result->message() . "\n";
		}

		$content = $result->decoded_content();
		$content =~ s/\r\n/\n/g;
		#print STDERR "Content: $content\n";

		$jsonref = decode_json($content);

		#print "DEBUG: $jsonref\n";
		#print "DEBUG: " . Dumper($jsonref) . "\n";
		if (ref($jsonref) eq "HASH" && defined $jsonref->{'error'})
		{
			die "Error when requesting host information from icinga API, message: $jsonref->{'error'}->[0]->{'message'}\nerrors: $jsonref->{'error'}->[0]->{'errors'}->[0]\n";
		}

		foreach $subhash (@$jsonref)
		{
			#print "DEBUG subhash: $subhash\n";
			#print "DEBUG host: $subhash->{'HOST_NAME'};Hoststatus = $services_state[$subhash->{'HOST_CURRENT_STATE'}]\n";
			#HOST_NAME
			#HOST_CURRENT_STATE
			#HOST_OUTPUT
	        	$hardstates{"$subhash->{'HOST_NAME'};Hoststatus"} = $host_state[$subhash->{'HOST_CURRENT_STATE'}] || "UNKNOWN";
	        	$statusinfos{"$subhash->{'HOST_NAME'};Hoststatus"} = $subhash->{'HOST_OUTPUT'}
		}
	}

	if ($dbparam{'cache_time'} > 0)
	{
		updateCache(\%hardstates, \%statusinfos);
	}
	return(\%hardstates, \%statusinfos);
}

sub getLastUpdateServiceStatus()
{
	my %dbparam = &getDbParam();
        my ($db_prefix, $return, $socket);

	if ($dbparam{'ndo'} eq "db")
	{
        	$db_prefix = $dbparam{'ndodb_prefix'};
        	$dbh = DBI->connect("DBI:mysql:$dbparam{'ndodb_database'}:$dbparam{'ndodb_host'}:$dbparam{'ndodb_port'}", $dbparam{'ndodb_username'}, $dbparam{'ndodb_password'});
	        die "Error: $DBI::errstr\n" unless $dbh;

	        $sql = "select max(last_check) from ${db_prefix}servicestatus";

	        $sth = $dbh->prepare($sql);
	        die "Error: $DBI::errstr\n" if $DBI::err;

	        $sth->execute();
	        die "Error: $DBI::errstr\n" if $DBI::err;

	        while (@fields = $sth->fetchrow_array())
	        {
	                #print join("\t", @fields), "\n";
			$return = $fields[0];
		}

	        $sth->finish();
	        $dbh->disconnect();
	}
	elsif ($dbparam{'ndo'} eq "fs")
	{
		$servicelist = $dbparam{'ndofs_basedir'} . "/VOLATILE/"  . $dbparam{'ndofs_instance_name'} . "/VIEWS/SERVICELIST";
		$parentdirname="$dbparam{'ndofs_basedir'}/VOLATILE/$dbparam{'ndofs_instance_name'}/HOSTS";

		open (LIST, "<$servicelist") or die "unable to read from file $servicelist\n";
		flock(LIST, LOCK_SH);

		while ($line = <LIST>)
		{
			chomp($line);
			# print "DEBUG: servicelist: $in\n";
			# DEBUG: servicelist:    "internetconnection":[
			# DEBUG: servicelist:       "Provider 1",
			# DEBUG: servicelist:       "Provider 2"
			# DEBUG: servicelist:    ],
			if ($line =~ m/"(.+)":\[/)
			{
				$hostname = cleanup_for_ndo2fs($1);
				#print "DEBUG: hostname:    $hostname\n";
			}
			if ($line =~ m/"(.+)",?\s*$/)
			{
				$servicename = cleanup_for_ndo2fs($1);
				#print "DEBUG: servicename: $hostname:$servicename\n";
				
				if (-e "$parentdirname/$hostname/$servicename/STATUS")
				{
					open (IN, "<$parentdirname/$hostname/$servicename/STATUS") or die "unable to read file $parentdirname/$hostname/$servicename/STATUS: $!\n";
					flock(IN, LOCK_SH);
					while ($in = <IN>)
						{
							if ($in =~ m/"LASTSERVICECHECK":\s*"(.*)"/)
							{
								#print "$1\n";
								if ($1 > $lastservicecheck)
								{
									$lastservicecheck = $1;
									#print "$lastservicecheck\n";
								}
							}
						}
					close(IN);
				}
			}
		}
		close(LIST);

		@lastservicecheck_local = localtime($lastservicecheck);
		$lastservicecheck_local[5]+=1900;
		$lastservicecheck_local[4] = sprintf("%02d", ++$lastservicecheck_local[4]);
		$lastservicecheck_local[3] = sprintf("%02d", $lastservicecheck_local[3]);
		$lastservicecheck_local[2] = sprintf("%02d", $lastservicecheck_local[2]);
		$lastservicecheck_local[1] = sprintf("%02d", $lastservicecheck_local[1]);
		$lastservicecheck_local[0] = sprintf("%02d", $lastservicecheck_local[0]);

		$return = "$lastservicecheck_local[5]-$lastservicecheck_local[4]-$lastservicecheck_local[3] $lastservicecheck_local[2]:$lastservicecheck_local[1]:$lastservicecheck_local[0]";
	}
	elsif ($dbparam{'ndo'} eq "merlin")
	{
        	$db_prefix = $dbparam{'ndodb_prefix'};
        	$dbh = DBI->connect("DBI:mysql:$dbparam{'ndodb_database'}:$dbparam{'ndodb_host'}:$dbparam{'ndodb_port'}", $dbparam{'ndodb_username'}, $dbparam{'ndodb_password'});
	        die "Error: $DBI::errstr\n" unless $dbh;

	        #$sql = "select max(last_check) from ${db_prefix}service";
	        $sql = "select max(last_check) from service";

	        $sth = $dbh->prepare($sql);
	        die "Error: $DBI::errstr\n" if $DBI::err;

	        $sth->execute();
	        die "Error: $DBI::errstr\n" if $DBI::err;

	        while (@fields = $sth->fetchrow_array())
	        {
	                #print join("\t", @fields), "\n";
			$return = $fields[0];
		}

	        $sth->finish();
	        $dbh->disconnect();
	}
	elsif ($dbparam{'ndo'} eq "mk_livestatus")
	{
		$socket = IO::Socket::UNIX->new ("Peer" => $dbparam{'ndo_livestatus_socket'}, "Type" => SOCK_STREAM, "Timeout" => 15) or die "unable to connect to unix socket \"" . $dbparam{'ndo_livestatus_socket'} . "\": $!\n";

		print $socket "GET services\n";
		print $socket "Stats: max last_check\n\n";

		$return = <$socket> || 0;
		chomp($return);
		#print STDERR "DEBUG: $return\n";
	}
	elsif ($dbparam{'ndo'} eq "icinga-web")
	{
		$return = 0;
		my $maxConnectionTime = 10;
		my ($ua, $request, $result, $content);
		if(substr($dbparam{'ndo_icinga_web_url_prefix'}, -1) eq "/")
		{
			$dbparam{'ndo_icinga_web_url_prefix'} = substr($dbparam{'ndo_icinga_web_url_prefix'}, 0, length($dbparam{'ndo_icinga_web_url_prefix'}) -1);
		}
	        my $services_url = $dbparam{'ndo_icinga_web_url_prefix'} . "/web/api/service/columns%5BSERVICE_LAST_CHECK%5D/authkey=" . $dbparam{'ndo_icinga_web_auth_key'} . "/json";

		#print STDERR "URL: $services_url\n";
		$ua = new LWP::UserAgent ( 'timeout' => $maxConnectionTime );
		$request = new HTTP::Request ('GET' => "$services_url");
		$result = $ua->request($request);

		if ($result->code() >= 400)
		{
			die "Error when requesting service information from icinga API, response code: " . $result->code() . ", message: " . $result->message() . "\n";
		}

		#print STDERR "Response Services: " . $result->code() . " " . $result->message() . "\n";
		$content = $result->decoded_content();
		$content =~ s/\r\n/\n/g;
		#print STDERR "Content: $content\n";

		$jsonref = decode_json($content);

		#print "DEBUG: $jsonref\n";
		#print "DEBUG: " . Dumper($jsonref) . "\n";
		foreach $subhash (@$jsonref)
		{
			#print "DEBUG update: $subhash->{'SERVICE_LAST_CHECK'}\n";
			if ($subhash->{'SERVICE_LAST_CHECK'} gt $return)
			{
				$return = $subhash->{'SERVICE_LAST_CHECK'};
			}
		}
	}

	return($return);
}

sub getDbParam()
{
	my (%dbparam, $in, $param, $value);

        open(IN, "<$dbConfigFile") or die "unable to read $dbConfigFile\n";
                while ($in = <IN>)
                {
                        if ($in =~ m/^\s*(ndodb_\w+|ndofs_\w+|ndo_livestatus_\w+|ndo_icinga_web_\w+|ndo|cache_\w+)\s*=/)
                        {
                                ($param, $value) = split(/=/, $in);
                                chomp($value);
				$value =~ s/^\s+//;
				$value =~ s/\s+$//;
				$param =~ s/^\s+//;
				$param =~ s/\s+$//;
                                $dbparam{$param} = $value;
                        }
                }
        close(IN);

	# set defaults, if we did not get values form config
	$dbparam{'ndo'}="db" if ($dbparam{'ndo'} eq "");
	$dbparam{'ndofs_basedir'}="/tmp/ndo2fs" if ($dbparam{'ndofs_basedir'} eq "");
	$dbparam{'ndofs_instance_name'}="default" if ($dbparam{'ndofs_instance_name'} eq "");
	$dbparam{'ndodb_host'}="localhost" if ($dbparam{'ndodb_host'} eq "");
	$dbparam{'ndodb_port'}="3306" if ($dbparam{'ndodb_port'} eq "");
	$dbparam{'ndodb_database'}="nagios" if ($dbparam{'ndodb_database'} eq "");
	$dbparam{'cache_time'}=0 if ($dbparam{'cache_time'} !~ m/^\d+$/);
	$dbparam{'cache_file'}="/tmp/ndo_backend_cache" if ($dbparam{'cache_file'} eq "");

	return (%dbparam);
}

sub getStatusFromFS()
{
	# gets one parameter (hostname) to determine the host status
	# gets two parameters (hostname and servicename) to determine the service status
	my $host = shift;
	my $service = shift || "Hoststatus";

	if ($service eq "Hoststatus")
	{
		if (-e "$parentdirname/$host/STATUS")
		{
			open (IN, "<$parentdirname/$host/STATUS") or die "unable to read file $parentdirname/$host/STATUS: $!\n";
			flock(IN, LOCK_SH);

				while($in = <IN>)
				{
					#print "DEBUG:        $in";
					if ($in =~ m/"CURRENTSTATE":\s*"(.*)"/)
					{
						#print "DEBUG:        LASTHARDSTATE: $1\n";
						$currentstate = $1;
					}
					if ($in =~ m/"OUTPUT":\s*"(.*)"/)
					{
						#print "DEBUG:        OUTPUT:        $1\n";
						$output = $1;
					}
					if ($in =~ m/"HOST":\s*"(.*)"/)
					{
						#print "DEBUG:        HOST:          $1\n";
						$hostname = $1;
					}
				}
			close(IN);
			$hardstates{"$hostname;Hoststatus"} = $host_state[$currentstate] || "UNKNOWN";
			$statusinfos{"$hostname;Hoststatus"} = $output;
		}
		else
		{
			$hardstates{"$hostname;Hoststatus"} = "PENDING";
			$statusinfos{"$hostname;Hoststatus"} = "";
		}
		#print "DEBUG:    $host;Hoststatus: $host_state[$currentstate]\n";
	}
	else
	{
		if (-e "$parentdirname/$host/$service/STATUS")
		{
			open (IN, "<$parentdirname/$host/$service/STATUS") or die "unable to read file $parentdirname/$host/$service/STATUS: $!\n";
			flock(IN, LOCK_SH);

				while($in = <IN>)
				{
					#print "DEBUG:        $in";
					# "OUTPUT": "OK: DNS",
					# "LASTHARDSTATE": "0",
					# "SERVICE": "System Check",
					if ($in =~ m/"LASTHARDSTATE":\s*"(.*)"/)
					{
						#print "DEBUG:        LASTHARDSTATE: $1\n";
						$lasthardstate = $1;
					}
					if ($in =~ m/"OUTPUT":\s*"(.*)"/)
					{
						#print "DEBUG:        OUTPUT:        $1\n";
						$output = $1;
					}
					if ($in =~ m/"SERVICE":\s*"(.*)"/)
					{
						#print "DEBUG:        SERVICE:       $1\n";
						$servicename = $1;
					}
				}
			close(IN);
			$hardstates{"$host;$servicename"} = $services_state[$lasthardstate] || "UNKNOWN";
			$statusinfos{"$host;$servicename"} = $output;
		}
		else
		{
			$hardstates{"$host;$servicename"} = "PENDING";
			$statusinfos{"$host;$servicename"} = "";
		}
		#print "DEBUG:    $host;$servicename: $host_state[$currentstate]\n";
	}
	return(0);
}

sub cleanup_for_ndo2fs {
	my $host_or_service_name = shift;
	$host_or_service_name =~ s/[ :\/\\]/_/g;
	return($host_or_service_name);
} 

#sub checkCache()
#{
#	my %dbparam = &getDbParam();
#	my $actDate=time();
#	my ($fileAge, @stat, $in, @tokens, $host, $service, $hardstate);
#
#	if ( -f $dbparam{'cache_file'} )
#	{
#		# ok, we have a cache file already
#		# print STDERR "cache_file exists\n";
#		@stat=stat($dbparam{'cache_file'});
#		$fileAge=$actDate-$stat[9];
#		# print STDERR "actDate: $actDate\n";
#		# print STDERR "FileModificationDate: $stat[9]\n";
#		# print STDERR "FileAge: $fileAge\n";
#
#		if ($fileAge <= $dbparam{'cache_time'})
#		{
#			# print STDERR "cache_file new enough, delivering from cache\n"; 
#			open(IN, "<$dbparam{'cache_file'}") or die "unable to read cachefile $dbparam{'cache_file'}\n";
#				flock(IN, LOCK_SH);
#				while ($in = <IN>)
#				{
#print STDERR "$in\n";
#					@tokens=split(/;/, $in);
#					$host=shift(@tokens);
#					$service=shift(@tokens);
#					$hardstate=shift(@tokens);
#					$hardstates{"$host;$service"} = $hardstate;
#					$statusinfos{"$host;$service"} = join(/;/, @tokens);
#					chomp($statusinfos{"$host;$service"});
#				}
#			close(IN);
#			return(\%hardstates, \%statusinfos);
#		}
#		else
#		{
#			# print STDERR "cache_file too old\n";
#			return('');
#		}
#	}
#	else
#	{
#		# print STDERR "cache_file does not exist\n";
#		return('');
#	}
#
#	return('');
#}

# call with parameters \%hardstates, \%statusinfos
sub updateCache()
{
	my %dbparam = &getDbParam();
	my $key;
	my $actDate=time();
	my @stat=stat($dbparam{'cache_file'});
	my $fileAge=$actDate-$stat[9];
	# print STDERR "actDate: $actDate\n";
	# print STDERR "FileModificationDate: $stat[9]\n";
	# print STDERR "FileAge: $fileAge\n";

	if ($fileAge > $dbparam{'cache_time'})
	{
		# print STDERR "DEBUG: writing cache_file\n";
		#print "DEBUG: hardstates\n";
		#printHash(\%hardstates);
		#print "DEBUG: statusinfos\n";
		#printHash(\%statusinfos);
		umask ("0000");
		open (OUT, ">$dbparam{'cache_file'}") or die "unable to write to $dbparam{'cache_file'}\n";
			flock(OUT, LOCK_EX);
			foreach $key (keys %hardstates)
			{
				print OUT "$key;$hardstates{$key};$statusinfos{$key}\n";
			}
		close (OUT);
	}
	#else
	#{
	#	print STDERR "DEBUG: someone else did write meanwile\n";
	#}
}
1;