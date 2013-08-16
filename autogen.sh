#!/bin/bash

# create structure
aclocal
autoconf
automake --add-missing

# rename files
mv cgi/bpview.pl cgi/bpview.pl.in
mv etc/bpview.yml etc/bpview.yml.in
mv sample-config/httpd.conf sample-config/httpd.conf.in

exit 0
