#!/bin/bash
#
# initialization script for new servers
# this was only tested and written for Ubuntu 12.04/14.04 LTS servers, but propably works on more linux distributions
# no warranty given at all, use with caution ;)

# minimal puppet installation
wget http://apt.puppetlabs.com/puppetlabs-release-$(lsb_release -cs).deb --quiet
dpkg -i puppetlabs-release-$(lsb_release -cs).deb
apt-get -qq update && apt-get -qqy install puppet

# setting puppet environment
# this expects that you have a unique environment naming scheme for your server hostnames
case "$(hostname)" in
    *jesse*)
        envname='test'
        ;;
    *walt*)
        envname='production'
        ;;
    *saul*)
        envname='reference'
        ;;
    *hank*)
        envname='dev'
        ;;
    *)
        envname='internal'
        ;;
esac

# setting puppet config file
puppetconf="/etc/puppet/puppet.conf"
sed -ie '/templatedir/d' $puppetconf
sed -ie '/environment/d' $puppetconf
sed -ie "/\[main\]/ a\environment=$envname" $puppetconf

# add puppetmaster ip to your hosts...just in case your dns server is not accessible yet
sed -ie '/puppetmaster/d' /etc/hosts
sed -ie '$ a\10.10.11.111    puppetmaster puppet' /etc/hosts

# trigger puppet run, waits 
initialrunlog="/var/log/puppet/agent-firstrun.log"
puppet agent --enable
puppet agent -tv --waitforcert=60 -l $initialrunlog
puppet agent -tv -l ${initialrunlog}

# uncomment the below line to mail your initial puppet run directly to your email account
#cat $initialrunlog | mail -s "NEW SERVER: $(hostname)/$(facter ipaddress) is ready for action" your@email.com
