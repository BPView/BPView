Name: bpview
Version: 0.1
Release: 2%{?dist}
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

Requires: perl
Requires: perl-CGI
Requires: perl-FCGI
Requires: perl-Log-Log4perl
Requires: perl-Template-Toolkit
Requires: perl-JSON
Requires: perl-YAML-Syck
Requires: perl-DBI
Requires: perl-DBD-Pg
Requires: perl-JSON-XS
Requires: perl-libwww-perl
Requires: mod_fcgid
Requires: httpd

%define apacheuser apache
%define apachegroup apache

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
           --with-web-user=%{apacheuser} \
           --with-web-group=%{apachegroup} \
           --with-web-conf=/etc/httpd/conf.d/bpview.conf

make all


%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT INSTALL_OPTS="" INSTALL_OPTS_WEB=""

%clean
rm -rf $RPM_BUILD_ROOT


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
%{_datarootdir}/%{name}
%attr(0755,%{apacheuser},%{apacheuser}) %{_localstatedir}/log/bpview.log
%doc AUTHORS ChangeLog COPYING NEWS README sample-config



%changelog
* Thu Aug 29 2013 Rene Koch <r.koch@ovido.at> 0.1-2
- added requirement for mod_fcgid and perl-FCGI

* Sun Aug 18 2013 Rene Koch <r.koch@ovido.at> 0.1-1
- Initial build.
