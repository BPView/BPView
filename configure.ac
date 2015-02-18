# Process this file with autoconf to produce a configure script.

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


AC_PREREQ([2.63])
AC_INIT([BPView], [0.10.1], [sales@ovido.at])
AM_INIT_AUTOMAKE

AC_PREFIX_DEFAULT(/usr/local/bpview)
PKG_NAME="bpview"
PKG_VERSION="0.10.1"
PKG_REL_DATE="2015-02-18"

# Figure out how to invoke "install" and what install options to use
AC_PROG_INSTALL
AC_SUBST(INSTALL)

# What OS are we running?
AC_CANONICAL_HOST

# Check for programs
AC_PATH_PROG([PERL],[perl])
AC_PROG_PERL_MODULES( Data::Dumper, , AC_MSG_ERROR(Missing Perl module Data::Dumper))
AC_PROG_PERL_MODULES( CGI, , AC_MSG_ERROR(Missing Perl module CGI))
AC_PROG_PERL_MODULES( CGI::Carp, , AC_MSG_ERROR(Missing Perl module CGI::Carp))
AC_PROG_PERL_MODULES( YAML::Syck, , AC_MSG_ERROR(Missing Perl module YAML::Syck))
AC_PROG_PERL_MODULES( Carp, , AC_MSG_ERROR(Missing Perl module Carp))
AC_PROG_PERL_MODULES( JSON::PP, , AC_MSG_ERROR(Missing Perl module JSON::PP))

# Options
AC_ARG_WITH(web_user,AC_HELP_STRING([--with-web-user=<user>],[username for web writable files (default apache)]),web_user=$withval,web_user=apache)
AC_ARG_WITH(web_group,AC_HELP_STRING([--with-web-group=<grp>],[groupname for web writable files (default apache)]),web_group=$withval,web_group=apache)
AC_ARG_WITH(web_conf,AC_HELP_STRING([--with-web-conf=<filepath>],[set path to BPView httpd config file (default /etc/httpd/conf.d/bpview.conf)]),web_conf=$withval,web_conf=/etc/httpd/conf.d/bpview.conf)
AC_ARG_ENABLE(ido_mysql,AC_HELP_STRING([--enable-ido-mysql],[enable IDOutils MySQL support (default: yes)]),ido_mysql=$enableval,ido_mysql=yes)
AC_ARG_ENABLE(ido_pgsql,AC_HELP_STRING([--enable-ido-pgsql],[enable IDOutils PostgreSQL support (default: yes)]),ido_pgsql=$enableval,ido_pgsql=yes)
#AC_ARG_ENABLE(mk_livestatus,AC_HELP_STRING([--enable-mk-livestatus],[enable mk-livetstatus support (default: yes)]),mk_livestatus=$enableval,mk_livestatus=yes)
AC_SUBST(web_user)
AC_SUBST(web_group)
AC_SUBST(web_conf)
AC_SUBST(ido_mysql)
AC_SUBST(ido_pgsql)
#AC_SUBST(mk_livestatus)

# check if perl modules are available based on enabled options
if test $ido_mysql = yes; then
  AC_PROG_PERL_MODULES( DBI, , AC_MSG_ERROR(Missing Perl module DBI))
fi

if test $ido_pgsql = yes; then
  AC_PROG_PERL_MODULES( DBI, , AC_MSG_ERROR(Missing Perl module DBI))
  AC_PROG_PERL_MODULES( DBD::Pg, , AC_MSG_ERROR(Missing Perl module DBD::Pg))
fi

#if test $mk_livestatus = yes; then
#  AC_PROG_PERL_MODULES( Digest::MD5, , AC_MSG_ERROR(Missing Perl module Digest::MD5))
#  AC_PROG_PERL_MODULES( Encode, , AC_MSG_ERROR(Missing Perl module Encode))
#  AC_PROG_PERL_MODULES( JSON::XS, , AC_MSG_ERROR(Missing Perl module JSON::XS))
#  AC_PROG_PERL_MODULES( IO::Socket::INET, , AC_MSG_ERROR(Missing Perl module IO::Socket::INET))
#  AC_PROG_PERL_MODULES( IO::Socket::UNIX, , AC_MSG_ERROR(Missing Perl module IO::Socket::UNIX))
#  AC_PROG_PERL_MODULES( Socket, , AC_MSG_ERROR(Missing Perl module Socket))
#  AC_PROG_PERL_MODULES( Config, , AC_MSG_ERROR(Missing Perl module Config))
#  AC_PROG_PERL_MODULES( Time::HiRes, , AC_MSG_ERROR(Missing Perl module Time::HiRes))
#  AC_PROG_PERL_MODULES( Scalar::Util, , AC_MSG_ERROR(Missing Perl module Scalar::Util))
#fi

INSTALL_OPTS=""
INSTALL_OPTS_WEB="-o $web_user -g $web_group"
AC_SUBST(INSTALL_OPTS)
AC_SUBST(INSTALL_OPTS_WEB)

AC_CONFIG_FILES([Makefile bin/Makefile cgi/Makefile etc/Makefile lib/Makefile log/Makefile share/Makefile])
AC_OUTPUT

# Review options
echo ""
echo ""
AC_MSG_RESULT([*** Configuration summary for $PKG_NAME $PKG_VERSION $PKG_REL_DATE ***:])
echo ""
echo ""
echo "     General Options:"
echo " ------------------------- -------------------------"
AC_MSG_RESULT([    web server user/group: $web_user,$web_group])
AC_MSG_RESULT([        Install \${prefix}: $prefix])
AC_MSG_RESULT([       Apache config file: $web_conf])
echo ""
echo "  Data Backend Options:"
echo " ------------------------- -------------------------"
AC_MSG_RESULT([         Enable IDO MySQL: $ido_mysql])
AC_MSG_RESULT([    Enable IDO PostgreSQL: $ido_pgsql])
#AC_MSG_RESULT([     Enable mk-livestatus: $mk_livestatus])
echo ""
echo ""
echo "Review the options above for accuray. If they look okay,"
echo "type 'make all' to compile."
echo ""
