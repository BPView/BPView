#!/bin/bash

# create structure
aclocal
autoconf
automake --add-missing

# rename files
mv bin/bpview_cfg_writer.pl bin/bpview_cfg_writer.pl.in
mv bin/check_bp_status bin/check_bp_status.in
mv cgi/bpview.pl cgi/bpview.pl.in
mv etc/bpview.yml etc/bpview.yml.in
mv etc/bp-addon.cfg etc/bp-addon.cfg.in
mv etc/datasource.yml etc/datasource.yml.in
mv sample-config/httpd.conf sample-config/httpd.conf.in
mv sample-config/icinga/objects/bpview_templates.cfg sample-config/icinga/objects/bpview_templates.cfg.in 

exit 0
