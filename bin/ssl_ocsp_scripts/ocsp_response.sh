#!/bin/sh
#
# prints the ocsp response
#
# ./ocsp_response.sh example.com

openssl s_client -connect $1:443 -tls1 -tlsextdebug -status | grep -A18 "OCSP response"
