#!/bin/bash

#
# serverlist has to be in the following format
#
# sol redhat 10.10.10.1     server1
# sol centos 10.10.202.66   host1
# int ubuntu 192.168.12.1   gateway
# int debian 192.168.12.17  virt1

ARGCOUNT=2
E_ARGERROR=85

if [ ! $# -ge $ARGCOUNT ]; then
  cat <<EOF
   Usage: $(basename $0) action object
   eg. $(basename $0) update bash
EOF
  exit $E_ARGERROR
fi  

source serverlist
thishost=$(hostname)

fssh() {
if [ $1 == "update" ]; then
	shift
	serverlist | grep -v '^#' | while read line; do
		#location="$(echo $line | awk '{print $1}')"
		distro="$(echo $line | awk '{print $3}')"
		#ip="$(echo $line | awk '{print $3}')"
		hostname="$(echo $line | awk '{print $5}')"
		if [ $thishost == $hostname ]; then continue; fi
		case $distro in
			debian|ubuntu) echo -e "====== $hostname ======";
			 ssh -x -- $hostname "DEBCONF_FRONTEND=noninteractive apt-get update >/dev/null ; apt-get -y -q --only-upgrade install $@" </dev/null ;;
			redhat|centos) echo -e "====== $hostname ======";
			 ssh -x -- $hostname "yum install $@" </dev/null;;
			*) echo -e "====== $hostname ======"
			   echo "meh $hostname";;
		esac
	done
elif [ $1 == "remove" ]; then
	shift
	serverlist | grep -v '^#' | while read line; do
		#location="$(echo $line | awk '{print $1}')"
		distro="$(echo $line | awk '{print $3}')"
		#ip="$(echo $line | awk '{print $3}')"
		hostname="$(echo $line | awk '{print $5}')"
		if [ $thishost == $hostname ]; then continue; fi
		case $distro in
			debian|ubuntu) echo -e "====== $hostname ======";
			 ssh -x -- $hostname "DEBCONF_FRONTEND=noninteractive apt-get update >/dev/null && apt-get -y -q remove $@" </dev/null ;;
			redhat|centos) echo -e "====== $hostname ======";
			 ssh -x -- $hostname "yum remove $@" </dev/null;;
			*) echo -e "====== $hostname ======"
			   echo "meh $hostname";;
		esac
	done
else
	shift
	serverlist | grep -v '^#' | while read line; do
		#location="$(echo $line | awk '{print $1}')"
		distro="$(echo $line | awk '{print $3}')"
		#ip="$(echo $line | awk '{print $3}')"
		hostname="$(echo $line | awk '{print $5}')"
		if [ $thishost == $hostname ]; then continue; fi
		case $distro in
			debian|ubuntu) echo -e "====== $hostname ======";
			 ssh -x -- $hostname "$@" </dev/null ;;
			redhat|centos) echo -e "====== $hostname ======";
			 ssh -x -- $hostname "$@" </dev/null;;
			*) echo "meh $hostname";;
		esac
	done
fi
}

case $1 in
   update|upgrade) 
      shift
      OBJECT="$@"
      fssh update $OBJECT;;
   remove) 
      shift
      OBJECT="$@"
      fssh remove $OBJECT;;
   ssh)
      shift
      OBJECT="$@"
      fssh other $OBJECT;;

   list)
      shift
      OBJECT="$1"
      serverlist | grep $OBJECT;;
   *) 
      echo wrong action;;
esac
