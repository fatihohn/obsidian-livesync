#!/bin/sh
set -e

mkdir -p /etc/cloudflare && \
echo "dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN" > /etc/cloudflare/cloudflare.ini && \
chmod 600 /etc/cloudflare/cloudflare.ini

set +e

# Request the certificate for the given domains
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/cloudflare/cloudflare.ini \
  --email $EMAIL_CERTIFICATOR \
  --agree-tos \
  --no-eff-email \
  -d crenology.com \
  -d obsidian-sync.crenology.com \
  --non-interactive --quiet --expand

set -e

# Set up the renewal loop
trap exit TERM; \
while :; do \
  sleep 6h & wait $!; \
  certbot renew --non-interactive --quiet; \
done

tail -f /dev/null
