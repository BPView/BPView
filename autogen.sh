#!/bin/bash

# create structure
aclocal
autoconf
automake --add-missing

# rename files
mv bin/bp-addon_config_writer.pl bin/bp-addon_config_writer.pl.in
mv cgi/bpview.pl cgi/bpview.pl.in
mv etc/bpview.yml etc/bpview.yml.in
mv etc/datasource.yml etc/datasource.yml.in
mv sample-config/httpd.conf sample-config/httpd.conf.in

exit 0
