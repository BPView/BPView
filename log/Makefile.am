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
LOCALSTATEDIR=@localstatedir@
INSTALL=@INSTALL@
INSTALL_OPTS_WEB=@INSTALL_OPTS_WEB@
WEB_USER=@web_user@
WEB_GROUP=@web_group@

# compile
all:

# install
install:
	for file in *.log; do \
	  $(INSTALL) -D -m 664 $(INSTALL_OPTS_WEB) $$file $(DESTDIR)$(LOCALSTATEDIR)/log/$$file; \
	done
	
# cleanup
clean:
