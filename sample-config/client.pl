use strict;
use warnings;
use IO::Socket::INET;
use JSON::PP;

#my $hash = { 'GET' => 'businessprocesses',
#	     'FILTER' => {'dashboard' => 'ovido'},
#};
my $hash = { 'GET' => 'services',
            'FILTER' => {'businessprocess' => 'kunden-bereitstellung_f_r_kunden-repositories',
                         #'state' => 'ok',
                         },
         };

my $json = JSON::PP->new->pretty;
$json->utf8('true');
$json = $json->encode($hash);
#my $json_text = encode_json $hash;

# auto-flush on socket
$| = 1;

# create a connecting socket
my $socket = new IO::Socket::INET (
    PeerHost => '127.0.0.1',
    PeerPort => '7777',
    Proto => 'tcp',
);
die "cannot connect to the server $!\n" unless $socket;
print "connected to the server\n";

# data to send to a server
#my $req = 'hello world';
my $size = $socket->send($json);
print $json;
print "sent data of length $size\n";

# notify server that request has been sent
shutdown($socket, 1);

# receive a response of up to 5024 characters from server
# adapt the number to get all data which is send.
my $response = "";
$socket->recv($response, 5024);
print "received response: $response\n";

$socket->close();

