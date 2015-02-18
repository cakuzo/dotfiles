#!/bin/bash
#
#  Copyright (C) 2014 by Dan Varga
#  dvarga@redhat.com
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.


host=$1
port=$2
timeout_bin=`which timeout`

if [ "$2" == "" ]
then
	port=443
fi

if [ -x "$timeout_bin" ]
then
	out="`echo x | timeout 5 openssl s_client -ssl3 -connect ${host}:${port} 2>/dev/null`"
else
	out="`echo x | openssl s_client -ssl3 -connect ${host}:${port} 2>/dev/null`"
fi

ret=$?

if [ $ret -eq 0 ]
then
	echo "VULNERABLE! SSLv3 detected."
	exit
elif [ $ret -eq 1 ]
then
	out=`echo $out | perl -pe 's|.*Cipher is (.*?) .*|$1|'`
	if [ "$out" == "0000" ] || [ "$out" == "(NONE)" ]
	then
		echo "Not Vulnerable. We detected that this server does not support SSLv3"
		exit
	fi
elif [ $ret -eq 124 ]
then
	echo "error: timeout connecting to host $host:$port"
	exit
fi
echo "error: Unable to connect to host $host:$port"
