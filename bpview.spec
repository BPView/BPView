Name: bpview
Version: 0.9
Release: 2%{?dist}
Summary: Business Process view for Nagios/Icinga 

Group: Applications/System
License: GPLv3+
URL: https://github.com/ovido/BPView
Source0: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildRequires: perl
BuildRequires: perl-CGI
BuildRequires: perl-JSON
BuildRequires: perl-YAML-Syck
BuildRequires: perl-DBI
BuildRequires: perl-DBD-Pg
BuildRequires: perl-libwww-perl
BuildRequires: selinux-policy

Requires: perl
Requires: perl-CGI
Requires: perl-FCGI
Requires: perl-Log-Log4perl
Requires: perl-Template-Toolkit
Requires: perl-JSON
Requires: perl-YAML-Syck
Requires: perl-DBI
Requires: perl-DBD-Pg
Requires: perl-DBD-MySQL
Requires: perl-JSON-XS
Requires: perl-libwww-perl
Requires: perl-Time-HiRes
Requires: perl-Crypt-SSLeay
Requires: perl-File-Copy-Recursive
Requires: perl-Proc-Daemon
Requires: mod_fcgid
Requires: httpd
Requires: perl-suidperl
Requires: perl-Tie-IxHash
Requires: perl-File-Pid
Requires: icinga
Requires: sudo

Requires(post):   /usr/sbin/semodule, /sbin/restorecon, /sbin/fixfiles
Requires(postun): /usr/sbin/semodule, /sbin/restorecon, /sbin/fixfiles

%define apacheuser apache
%define apachegroup apache
%define icingauser icinga
%define icingagroup icingacmd

%global selinux_variants mls targeted

%description
BPView is the short name for Business Process View. This Tool
for Nagios and Icinga is used to display a combination of Checks
in a Business Process.

%prep
%setup -q -n %{name}-%{version}

%build
%configure --prefix=/usr \
           --sbindir=%{_libdir}/%{name} \
           --libdir=%{_libdir}/perl5/vendor_perl \
           --sysconfdir=%{_sysconfdir}/%{name} \
           --datarootdir=%{_datarootdir}/%{name} \
           --docdir=%{_docdir}/%{name}-%{version} \
           --with-web-user=%{apacheuser} \
           --with-web-group=%{apachegroup} \
           --with-web-conf=/etc/httpd/conf.d/bpview.conf

cd selinux
for selinuxvariant in %{selinux_variants}
do
  make NAME=${selinuxvariant} -f /usr/share/selinux/devel/Makefile
  mv %{name}.pp %{name}.pp.${selinuxvariant}
  make NAME=${selinuxvariant} -f /usr/share/selinux/devel/Makefile clean
done
cd -

make all


%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT INSTALL_OPTS="" INSTALL_OPTS_WEB=""

# backup folder
mkdir -p $RPM_BUILD_ROOT/%{_sysconfdir}/%{name}/backup

for selinuxvariant in %{selinux_variants}
do
  install -d %{buildroot}%{_datadir}/selinux/${selinuxvariant}
  install -p -m 644 selinux/%{name}.pp.${selinuxvariant} \
    %{buildroot}%{_datadir}/selinux/${selinuxvariant}/%{name}.pp
done


%clean
rm -rf $RPM_BUILD_ROOT


%post
for selinuxvariant in %{selinux_variants}
do
  /usr/sbin/semodule -s ${selinuxvariant} -i \
    %{_datadir}/selinux/${selinuxvariant}/%{name}.pp &> /dev/null || :
done
/sbin/fixfiles -R %{name} restore || :
/sbin/restorecon -R %{_localstatedir}/cache/%{name} || :
/usr/sbin/setsebool -P allow_ypbind=on

%postun
if [ $1 -eq 0 ] ; then
  for selinuxvariant in %{selinux_variants}
  do
    /usr/sbin/semodule -s ${selinuxvariant} -r %{name} &> /dev/null || :
  done
  /sbin/fixfiles -R %{name} restore || :
  [ -d %{_localstatedir}/cache/%{name} ]  && \
    /sbin/restorecon -R %{_localstatedir}/cache/%{name} &> /dev/null || :
fi


%files
%defattr(-,root,root)
%config(noreplace) %{_sysconfdir}/%{name}/bpview.yml
%config(noreplace) %{_sysconfdir}/%{name}/datasource.yml
%config(noreplace) %{_sysconfdir}/%{name}/views
%config(noreplace) %{_sysconfdir}/%{name}/backup
%config(noreplace) %{_sysconfdir}/%{name}/bp-config
%config(noreplace) %{_sysconfdir}/httpd/conf.d/bpview.conf
%config(noreplace) %{_sysconfdir}/sudoers.d/bpview
%{_libdir}/perl5/vendor_perl
%attr(0755,root,root) %{_libdir}/%{name}/plugins/check_bp_status.pl
%attr(0755,root,root) %{_libdir}/%{name}/bpview.pl
%attr(0755,root,root) %{_bindir}/bpviewd
%attr(0755,root,root) %{_bindir}/bpview_reload
%attr(0775,root,apache) %{_sysconfdir}/%{name}/bp-config
%attr(0775,root,apache) %{_sysconfdir}/%{name}/views
%attr(0775,root,apache) %{_sysconfdir}/%{name}/backup
%attr(0775,root,apache) %{_sysconfdir}/%{name}/icinga
%attr(0664,root,apache) %{_sysconfdir}/%{name}/icinga/bpview_templates.cfg
%attr(0664,root,apache) %{_sysconfdir}/%{name}/icinga/bpview_businessprocesses.cfg
%attr(0775,root,root) %{_sysconfdir}/init.d/bpviewd
%{_datarootdir}/%{name}/css
%{_datarootdir}/%{name}/images
%{_datarootdir}/%{name}/javascript
%{_datarootdir}/%{name}/src
%{_datadir}/selinux/*/%{name}.pp
%attr(0755,%{apacheuser},%{apachegroup}) %{_localstatedir}/log/%{name}
%attr(0755,%{apacheuser},%{apachegroup}) %{_localstatedir}/log/%{name}/bpview.log
%doc AUTHORS ChangeLog COPYING NEWS README.md sample-config selinux



%changelog
* Fri Apr 25 2014 Rene Koch <rkoch@linuxland.at> 0.9-2
- cleanup of old files

* Mon Apr 07 2014 Rene Koch <rkoch@linuxland.at> 0.9-1
- bump to 0.9
- Removed BuildRequires of EPEL packages
- Added bpview_reload script 

* Thu Mar 13 2014 Rene Koch <rkoch@linuxland.at> 0.8-2
- Fixed name of bpviewd init script
- Fixed permissions for /etc/bpview/backup folder

* Thu Mar 06 2014 Rene Koch <rkoch@linuxland.at> 0.8-1
- bump to 0.8
- requires perl-Proc-Daemon

* Thu Nov 21 2013 Rene Koch <r.koch@ovido.at> 0.7-2
- changed log file path to /var/log/bpview/bpview.log

* Thu Nov 21 2013 Rene Koch <r.koch@ovido.at> 0.7-1
- bump to 0.7
- added bpviewd
- requires perl-File-Pid

* Wed Nov 06 2013 Rene Koch <r.koch@ovido.at> 0.6-1
- bump to 0.6
- renamed README to README.md

* Tue Oct 29 2013 Rene Koch <r.koch@ovido.at> 0.5-1
- bump to 0.5
- removed bp-addon.cfg
- requires icinga, sudo
- /etc/sudoers.d/bpview added
- write permissions for apache on bpview/icinga config directory
- added bpview_businessprocesses.cfg
- create backup folder

* Thu Sep 5 2013 Peter Stoeckl <p.stoeckl@ovido.at> 0.1-5
- some changes

* Thu Aug 29 2013 Rene Koch <r.koch@ovido.at> 0.1-4
- added SELinux support

* Thu Aug 29 2013 Rene Koch <r.koch@ovido.at> 0.1-3
- added requirement for perl-Crypt-SSLeay, perl-Time-HiRes and perl-DBD-MySQL

* Thu Aug 29 2013 Rene Koch <r.koch@ovido.at> 0.1-2
- added requirement for mod_fcgid and perl-FCGI

* Sun Aug 18 2013 Rene Koch <r.koch@ovido.at> 0.1-1
- Initial build.
