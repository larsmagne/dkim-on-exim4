#!/bin/bash

set -e

domain="$1"

if [ "$domain" = "" ]; then
    echo "Usage: $0 domain-name"
    exit
fi

# Generate private and public keys.
openssl genrsa -out "$domain-dkim-private.pem" 2048 2>/dev/null
openssl rsa -in "$domain-dkim-private.pem" -out "$domain-dkim-public.pem" -pubout 2>/dev/null

# Allow exim to read the file.
chmod g+r "$domain-dkim-private.pem"
chgrp Debian-exim "$domain-dkim-private.pem"


selector=$(date +%Y%m%d)

DKIM="DKIM_CANON = relaxed
DKIM_SELECTOR = $selector
DKIM_DOMAIN = $domain
DKIM_PRIVATE_KEY = /etc/exim4/$domain-dkim-private.pem
"

if [ -e exim4.conf ]; then
    # Single file.
    mv exim4.conf exim4.conf.safe
    (echo "$DKIM"; cat exim4.conf.safe) > exim4.conf
else
    # Split configuration.
    echo "$DKIM" > conf.d/main/00_dkim_macros
    update-exim4.conf
fi

service exim4 reload

echo "Make the following TXT DNS record for $selector._domainkey.$domain"
echo
echo -n "k=rsa; p="
grep -v '^-' < "$domain-dkim-public.pem" | tr -d '\n'
echo
