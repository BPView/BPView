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
CGIDIR=@sbindir@
LIBDIR=@libdir@
SYSCONFDIR=@sysconfdir@
LOCALSTATEDIR=@localstatedir@
INSTALL=@INSTALL@
INSTALL_OPTS=@INSTALL_OPTS@
SCRIPT=bpview

# compile
all:
	cp $(SCRIPT).pl.in $(SCRIPT).tmp
	sed -i -e 's!lib_path = .*!lib_path = "$(LIBDIR)";!' $(SCRIPT).tmp
	sed -i -e 's!cfg_path = .*!cfg_path = "$(SYSCONFDIR)";!' $(SCRIPT).tmp
	sed -i -e 's!$reload_log = .*!$reload_log = "$(LOCALSTATEDIR)/log/bpview/reload.log";!' $(SCRIPT).tmp
	cp $(SCRIPT).tmp $(SCRIPT).pl
	rm -f $(SCRIPT).tmp

# install
install:
	for file in *.pl; do \
	  $(INSTALL) -D -m 755 $(INSTALL_OPTS) $$file $(DESTDIR)$(CGIDIR)/$$file; \
	done

# cleanup
clean:
	rm -f *.pl
