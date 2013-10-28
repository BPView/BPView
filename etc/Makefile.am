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
SYSCONFDIR=@sysconfdir@
DATAROOTDIR=@datarootdir@
LIBDIR=@libdir@
LOCALSTATEDIR=@localstatedir@
INSTALL=@INSTALL@
INSTALL_OPTS=@INSTALL_OPTS@
CONF=bpview
BPCONF=bp-addon
CONTACTGROUP=admins

# compile
all:
	cp $(CONF).yml.in $(CONF).tmp
	sed -i -e 's!^  data_dir:.*!  data_dir: $(DATAROOTDIR)!' $(CONF).tmp
	sed -i -e 's!^  src_dir:.*!  src_dir: $(DATAROOTDIR)/src!' $(CONF).tmp
	sed -i -e 's!^  logfile:.*!  logfile: $(LOCALSTATEDIR)/log/bpview.log!' $(CONF).tmp
	cp $(CONF).tmp $(CONF).yml
	cp datasource.yml.in datasource.yml
	rm -f $(CONF).tmp

	cp $(BPCONF).yml.in $(BPCONF).tmp
	cp $(BPCONF).tmp $(BPCONF).yml
	rm -f $(BPCONF).tmp

# install
install:
	for file in *.yml views/*.yml bp-config/*.yml; do \
	  $(INSTALL) -D -m 644 $(INSTALL_OPTS) $$file $(DESTDIR)$(SYSCONFDIR)/$$file; \
	done

	
# cleanup
clean:
	rm -f *.yml
