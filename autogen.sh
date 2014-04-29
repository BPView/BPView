#!/bin/bash

# create structure
aclocal
autoconf
automake --add-missing

# rename files
mv bin/bpviewd.pl bin/bpviewd.pl.in
mv bin/check_bp_status.pl bin/check_bp_status.pl.in
mv bin/bpview_reload.pl bin/bpview_reload.pl.in
mv cgi/bpview.pl cgi/bpview.pl.in
mv etc/bpview.yml etc/bpview.yml.in
mv etc/datasource.yml etc/datasource.yml.in
mv sample-config/httpd.conf sample-config/httpd.conf.in
mv sample-config/bpview_templates.cfg sample-config/bpview_templates.cfg.in 

exit 0
