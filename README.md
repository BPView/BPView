     ______   _____  _    _ _____ _______ _  _  _      
     |_____] |_____]  \  /    |   |______ |  |  |      
     |_____] |         \/   __|__ |______ |__|__|      
        MONITORING Business Process Dashboard          

# NAME

BPView - Business Process Dashboard for Monitoring Environments

# DESCRIPTION

BPView is a webbased monitoring application for collect, manage and view
business processes based on some monitoring environments such as Nagios,
Icinga, and more.

#REQUIREMENTS

Make sure the following requirements are fulfilled:
  * Webserver (apache or nginx)
  * Perl
  * Perl Modules:
    - CGI
    - CGI::Carp
    - CGI::Fast
    - YAML::Syck
    - File::Spec
    - JSON::PP
    - LWP::UserAgent
    - HTTP::Request
    - HTTP::Request::Common
    - Data::Dumper
    - Template
    - DBI
    - DBD::Pg
    - Log4perl
    - Tie::IxHash
    

When installing BPView via RPM package all dependencies are resolved automatically:
    # yum install bpview

## Installation of mod_fcgid (recommended)

    # yum install mod_fcgid
  
    Load mod_fcgid module
    # vi /etc/httpd/conf/httpd.conf
    LoadModule fcgid_module modules/mod_fcgid.so
  
    Restart Apache
    # service httpd restart



# AUTHOR

- René Koch (scrat14) _<r.koch@ovido.at>_ ( Blog: [http://ovido.at/blog](http://ovido.at/blog) )
- Peter Stöckl (PetziAt) _<p.stoeckl@ovido.at>_ ( Blog: [http://ovido.at/blog](http://ovido.at/blog) )

## CONTRIBUTORS

- 

## SPONSORS

Parts of this code were paid for by

- ovido gmbh [http://www.ovido.at/](http://www.ovido.at/)
- ERSTE GROUP IT [http://www.erstegroupit.com/at-en](http://www.erstegroupit.com/at-en)


# COPYRIGHT

Copyright (c) 2013 the BPView ["AUTHOR"](#AUTHOR), ["CONTRIBUTORS"](#CONTRIBUTORS), and ["SPONSORS"](#SPONSORS) as listed above.

# LICENSE

This library is free software and may be distributed under the same terms as perl itself.

## AVAILABILITY

The most current version of BPview can be found at [https://github.com/BPView](https://github.com/BPView)

  
