#!/bin/sh
#
# a simple script for checking oscp functionality
#

CERTPATH="/etc/ssl/path/to/your/cert/directory"
CERT="${CERTPATH}/certificate.pem"
CAROOT="${CERTPATH}/COMODORSAOrganizationValidationSecureServerCA.crt"
OCSP_URI="$(openssl x509 -in ${CERT} -text | grep OCSP | sed 's/\(.*URI.\)\(http.*\)/\2/')"
OCSP_HOST="$(echo ${OCSP_URI} | sed 's/http:..//')"
HAPROXY_STAT="/var/run/haproxy.stat"

/usr/bin/env openssl ocsp -noverify -issuer $CAROOT -cert $CERT -url "$OCSP_URI"
