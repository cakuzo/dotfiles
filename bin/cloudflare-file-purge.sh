#!/bin/bash
#
# this is just a simple cloudflare api test
#

source cloudflare.credentials

curl https://www.cloudflare.com/api_json.html \
  -d "a=zone_file_purge" \
  -d "tkn=$api_tkn" \
  -d "email=$account" \
  -d "z=$zone" \
  -d "url=http://www.$zone/$file_to_purge"
