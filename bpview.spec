Name: bpview
Version: 0.1
Release: 4%{?dist}
Summary: Business Process view for Nagios/Icinga 

Group: Applications/System
License: GPLv3+
URL: https://github.com/ovido/BPView
Source0: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildRequires: perl
BuildRequires: perl-CGI
BuildRequires: perl-Log-Log4perl
BuildRequires: perl-Template-Toolkit
BuildRequires: perl-JSON
BuildRequires: perl-YAML-Syck
BuildRequires: perl-DBI
BuildRequires: perl-DBD-Pg
BuildRequires: perl-JSON-XS
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
Requires: mod_fcgid
Requires: httpd

Requires(post):   /usr/sbin/semodule, /sbin/restorecon, /sbin/fixfiles
Requires(postun): /usr/sbin/semodule, /sbin/restorecon, /sbin/fixfiles

%define apacheuser apache
%define apachegroup apache

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
%config(noreplace) %{_sysconfdir}/%{name}/bp-config
%config(noreplace) %{_sysconfdir}/httpd/conf.d/bpview.conf
%{_libdir}/perl5/vendor_perl
%attr(0755,root,root) %{_libdir}/%{name}/bpview.pl
%attr(0755,root,root) %{_bindir}/bp-addon_config_writer.pl
%{_datarootdir}/%{name}/css
%{_datarootdir}/%{name}/images
%{_datarootdir}/%{name}/javascript
%{_datarootdir}/%{name}/src
%{_datadir}/selinux/*/%{name}.pp
%attr(0755,%{apacheuser},%{apacheuser}) %{_localstatedir}/log/bpview.log
%doc AUTHORS ChangeLog COPYING NEWS README sample-config selinux



%changelog
* Thu Aug 29 2013 Rene Koch <r.koch@ovido.at> 0.1-4
- added SELinux support

* Thu Aug 29 2013 Rene Koch <r.koch@ovido.at> 0.1-3
- added requirement for perl-Crypt-SSLeay, perl-Time-HiRes and perl-DBD-MySQL

* Thu Aug 29 2013 Rene Koch <r.koch@ovido.at> 0.1-2
- added requirement for mod_fcgid and perl-FCGI

* Sun Aug 18 2013 Rene Koch <r.koch@ovido.at> 0.1-1
- Initial build.
