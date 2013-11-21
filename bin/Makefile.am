# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

# compiler settings
BINDIR=@bindir@
LIBDIR=@libdir@
CGIDIR=@sbindir@
SYSCONFDIR=@sysconfdir@
INSTALL=@INSTALL@
INSTALL_OPTS=@INSTALL_OPTS@
SCRIPT1=bpview_cfg_writer
SCRIPT2=check_bp_status
SCRIPT3=bpviewd

# compile
all:
	cp $(SCRIPT1).pl.in $(SCRIPT1).tmp
	sed -i -e 's!lib_path = .*!lib_path = "$(LIBDIR)";!' $(SCRIPT1).tmp
	sed -i -e 's!cfg_path = .*!cfg_path = "$(SYSCONFDIR)";!' $(SCRIPT1).tmp
	cp $(SCRIPT1).tmp $(SCRIPT1).pl
	rm -f $(SCRIPT1).tmp

	cp $(SCRIPT2).pl.in $(SCRIPT2).tmp
	sed -i -e 's!lib_path = .*!lib_path = "$(LIBDIR)";!' $(SCRIPT2).tmp
	sed -i -e 's!cfg_path = .*!cfg_path = "$(SYSCONFDIR)";!' $(SCRIPT2).tmp
	cp $(SCRIPT2).tmp $(SCRIPT2).pl
	rm -f $(SCRIPT2).tmp
	
	cp $(SCRIPT3).pl.in $(SCRIPT3).tmp
	sed -i -e 's!lib_path = .*!lib_path = "$(LIBDIR)";!' $(SCRIPT3).tmp
	sed -i -e 's!cfg_path = .*!cfg_path = "$(SYSCONFDIR)";!' $(SCRIPT3).tmp
	cp $(SCRIPT3).tmp $(SCRIPT3)
	rm -f $(SCRIPT3).tmp



# install
install:
	for file in $(SCRIPT1).pl $(SCRIPT3); do \
	  $(INSTALL) -D -m 755 $(INSTALL_OPTS) $$file $(DESTDIR)$(BINDIR)/$$file; \
	done
	for file in $(SCRIPT2).pl; do \
	  $(INSTALL) -D -m 755 $(INSTALL_OPTS) $$file $(DESTDIR)$(CGIDIR)/plugins/$$file; \
	done

# cleanup
clean:
	rm -f *.pl
	rm -f $(SCRIPT3)

