#!/bin/sh
#
# this was tested with COMODO CA
#
# quick&dirty script for ocsp generation with ocsp.comodoca.com
#

# configuration
HAPROXY_STAT="/var/run/haproxy.stat"
CERTPATH="/etc/ssl/path/to/your/certificate/directory"
TLD="example.com"
CERT="${CERTPATH}/certificate.pem" # cert and intermediate certs
CAROOT="${CERTPATH}/COMODORSAOrganizationValidationSecureServerCA.crt" # root ca 
CERTBUNDLE="${CERTPATH}/certbundle.pem" # all in once
LEVEL1="${CERTPATH}/level1.pem" # 

# getting ocsp url 
OCSP_URL="$(openssl x509 -in ${CERT} -text | grep OCSP | sed 's/\(.*URI.\)\(http.*\)/\2/')" # http://ocsp.comodoca.com
OCSP_HOST="$(echo ${OCSP_URL} | sed 's/http:..//')" # ocsp.comodoca.com

# creating level1 and fetching serial
echo -n "" | /usr/bin/openssl s_client -connect ${TLD}:443 -showcerts > ${CERTBUNDLE} && cat ${CERTBUNDLE} | grep -A 1000 "1 s:" > ${LEVEL1}
SERIAL="$(openssl x509 -in ${CERTBUNDLE} -serial -noout | sed 's/serial=/0x/')"

# updating ocsp response
/usr/bin/openssl ocsp -no_nonce -header Host ${OCSP_HOST} -issuer ${LEVEL1} -serial ${SERIAL} -url ${OCSP_URL} -VAfile ${LEVEL1} \
-respout ${CERT}.ocsp && echo "set ssl ocsp-response $(/usr/bin/base64 -w 10000 ${CERT}.ocsp)" | /usr/bin/socat stdio ${HAPROXY_STAT}
