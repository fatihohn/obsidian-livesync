#!/bin/bash

# Obsidian LiveSync Startup Script for ARM64 Oracle Cloud
set -e

echo "🚀 Starting Obsidian LiveSync setup..."

# Check if running on ARM64
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" ]] && [[ "$ARCH" != "arm64" ]]; then
    echo "⚠️  Warning: This setup is optimized for ARM64 architecture. Current: $ARCH"
fi

# Check if Docker and Docker Compose are installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

# Check environment variables
if [ ! -f .env ]; then
    echo "❌ .env file not found. Please create and configure your environment variables."
    exit 1
fi

if [ ! -f certbot/.env ]; then
    echo "❌ certbot/.env file not found. Please configure your Cloudflare credentials."
    exit 1
fi

# Load environment variables
source .env

echo "✅ Environment loaded"
echo "   Domain: ${DOMAIN}"
echo "   CouchDB User: ${COUCHDB_USER}"
echo "   SSL Enabled: ${SSL_ENABLED}"

# Make scripts executable
chmod +x couchdb-init.sh

echo "✅ Scripts made executable"

# Create necessary directories
mkdir -p letsencrypt
mkdir -p certbot/www

echo "✅ Directories created"

wait_for_couchdb() {
  echo "⏳ Waiting for CouchDB to become healthy..."
  local deadline=$((SECONDS+600)) # wait up to 10 minutes
  while true; do
    status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}unknown{{end}}' obsidian-livesync-db 2>/dev/null || echo unknown)
    if [ "$status" = "healthy" ]; then
      echo "✅ CouchDB is healthy"
      return 0
    fi
    if (( SECONDS > deadline )); then
      echo "❌ Timeout waiting for CouchDB health (last status: $status)"
      echo "— Recent CouchDB logs —"
      docker compose logs --tail=200 couchdb || true
      return 1
    fi
    sleep 5
  done
}

# Start services
echo "🔧 Starting services..."

if [ "${SSL_ENABLED}" = "true" ]; then
    echo "🔒 SSL is enabled - starting certbot and CouchDB first"
    docker compose up -d couchdb certbot
    wait_for_couchdb
    # Start plugin after DB is healthy
    docker compose up -d livesync-plugin

    echo "⏳ Waiting for certificate generation..."
    sleep 30

    # Check if certificates were generated
    if [ -f "letsencrypt/live/crenology.com/fullchain.pem" ]; then
        echo "✅ SSL certificates generated successfully"
        # Now start nginx
        docker compose up -d nginx
    else
        echo "⚠️  SSL certificates not found. Starting in HTTP mode for now..."
        # Modify nginx.conf temporarily for HTTP-only mode
        cp nginx.conf nginx.conf.backup
        sed -i 's/return 301 https/# return 301 https/g' nginx.conf
        docker compose up -d nginx
        echo "💡 You can enable HTTPS later by running certbot manually"
    fi
else
    echo "🌐 Starting in HTTP mode (SSL disabled)"
    # Comment out HTTPS redirect in nginx.conf
    cp nginx.conf nginx.conf.backup
    sed -i 's/return 301 https/# return 301 https/g' nginx.conf
    # Start DB first, wait, then others
    docker compose up -d couchdb
    wait_for_couchdb
    docker compose up -d livesync-plugin nginx
fi

echo ""
echo "🎉 Obsidian LiveSync is starting up!"
echo ""
echo "📊 Check status with:"
echo "   docker compose ps"
echo ""
echo "📋 View logs with:"
echo "   docker compose logs -f"
echo ""
echo "🌐 Access points:"
if [ "${SSL_ENABLED}" = "true" ]; then
    echo "   CouchDB: https://${DOMAIN} (Fauxton: https://${DOMAIN}/_utils)"
    echo "   LiveSync: https://${DOMAIN}"
else
    echo "   CouchDB: http://${DOMAIN} (Fauxton: http://${DOMAIN}/_utils)"
    echo "   LiveSync: http://${DOMAIN}"
fi
echo "   Plugin server: http://${DOMAIN}:8080"
echo ""
echo "🔧 Next steps:"
echo "   1. Configure your Obsidian LiveSync plugin"
echo "   2. Create a database in CouchDB"
echo "   3. Set up your vault synchronization"
echo ""
echo "📖 For detailed setup instructions, see README-docker.md"
