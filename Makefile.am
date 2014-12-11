# COPYRIGHT:
#
# This software is Copyright (c) 2013 by ovido
#                            (c) 2014 BPView Development Team
#                                     http://github.com/BPView/BPView
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

# directories
BIN_DIR=@srcdir@/bin
CGI_DIR=@srcdir@/cgi
ETC_DIR=@srcdir@/etc
LIB_DIR=@srcdir@/lib
LOG_DIR=@srcdir@/log
SHARE_DIR=@srcdir@/share
SELINUX_DIR=@srcdir@/selinux
DOCDIR=@docdir@
WEBCONF=@web_conf@
HTTPCONF=httpd
INITRH6=bpview.rh6.init
BPVIEWTMPL=bpview_templates
CGIDIR=@sbindir@
BINDIR=@bindir@
ETCDIR=@sysconfdir@
DATAROOTDIR=@datarootdir@
LOCALSTATEDIR=@localstatedir@

PACKAGE=@PACKAGE@
VERSION=@VERSION@

distdir=$(PACKAGE)-$(VERSION)
DIST_COMMON=config.sub configure.ac configure NEWS INSTALL missing aclocal.m4 install-sh Makefile.am ChangeLog COPYING README.md AUTHORS Makefile.in config.guess autogen.sh bpview.spec
DISTFILES=$(DIST_COMMON) $(BIN_DIR) $(CGI_DIR) $(ETC_DIR) $(LIB_DIR) $(LOG_DIR) $(SHARE_DIR) $(SELINUX_DIR) sample-config docs tools bpview.rh6.init.in

# compiler settings
prefix=@prefix@
INSTALL=@INSTALL@
INSTALL_OPTS=@INSTALL_OPTS@

# Compile
all:
	cd $(BIN_DIR) && $(MAKE) $@
	cd $(CGI_DIR) && $(MAKE) $@
	cd $(ETC_DIR) && $(MAKE) $@
	cd $(LIB_DIR) && $(MAKE) $@
	cd $(LOG_DIR) && $(MAKE) $@
	cd $(SHARE_DIR) && $(MAKE) $@
	
	cp sample-config/$(HTTPCONF).conf.in sample-config/$(HTTPCONF).tmp
	sed -i 's!/data/www/BPView/cgi!$(CGIDIR)!' sample-config/$(HTTPCONF).tmp
	sed -i 's!/data/www/BPView/share!$(DATAROOTDIR)!' sample-config/$(HTTPCONF).tmp
	cp sample-config/$(HTTPCONF).tmp sample-config/$(HTTPCONF).conf
	rm -f sample-config/$(HTTPCONF).tmp
	
	cp $(INITRH6).in $(INITRH6).tmp
	sed -i -e 's!PROG_BIN=.*!PROG_BIN="$(BINDIR)/bpviewd"!' $(INITRH6).tmp
	sed -i -e 's!PID_FILE=.*!PID_FILE="$(LOCALSTATEDIR)/run/bpviewd.pid"!' $(INITRH6).tmp
	cp $(INITRH6).tmp $(INITRH6)
	rm -f $(INITRH6).tmp
	

# Install
install:
	cd $(BIN_DIR) && $(MAKE) $@
	cd $(CGI_DIR) && $(MAKE) $@
	cd $(ETC_DIR) && $(MAKE) $@
	cd $(LIB_DIR) && $(MAKE) $@
	cd $(LOG_DIR) && $(MAKE) $@
	cd $(SHARE_DIR) && $(MAKE) $@
	
	for file in AUTHORS ChangeLog COPYING NEWS README.md sample-config/*; do \
	  $(INSTALL) -D -m 644 $(INSTALL_OPTS) $$file $(DESTDIR)$(DOCDIR)/$$file; \
	done
	
	$(INSTALL) -D -m 644 $(INSTALL_OPTS) sample-config/httpd.conf $(DESTDIR)$(WEBCONF)
	$(INSTALL) -D -m 440 $(INSTALL_OPTS) sample-config/sudoers $(DESTDIR)/etc/sudoers.d/bpview
	
	$(INSTALL) -D -m 775 $(INSTALL_OPTS) bpview.rh6.init $(DESTDIR)/etc/init.d/bpviewd

# Cleanup
clean:
	cd $(BIN_DIR) && $(MAKE) $@
	cd $(CGI_DIR) && $(MAKE) $@
	cd $(ETC_DIR) && $(MAKE) $@
	cd $(LIB_DIR) && $(MAKE) $@
	cd $(LOG_DIR) && $(MAKE) $@
	cd $(SHARE_DIR) && $(MAKE) $@
	
	rm -f sample-config/*.conf
