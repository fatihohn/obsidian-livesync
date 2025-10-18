#!/bin/bash

# Wait for CouchDB to be ready
sleep 10

# Function to check if CouchDB is ready
check_couchdb() {
    curl -s -f http://localhost:5984/_up > /dev/null
    return $?
}

# Wait for CouchDB to be available
echo "Waiting for CouchDB to be ready..."
while ! check_couchdb; do
    echo "CouchDB not ready yet, waiting..."
    sleep 5
done

echo "CouchDB is ready, initializing..."

# Create admin user if it doesn't exist
curl -X PUT http://localhost:5984/_node/_local/_config/admins/${COUCHDB_USER} \
     -d "\"${COUCHDB_PASSWORD}\"" \
     -H "Content-Type: application/json" || true

# Ensure system databases exist (idempotent PUT requests)
for db in _users _replicator _global_changes; do
    echo "Ensuring system database '${db}' exists..."
    curl -X PUT http://${COUCHDB_USER}:${COUCHDB_PASSWORD}@localhost:5984/${db} \
         -s -o /dev/null || true
done

# Enable CORS
curl -X PUT http://${COUCHDB_USER}:${COUCHDB_PASSWORD}@localhost:5984/_node/_local/_config/httpd/enable_cors \
     -d '"true"' \
     -H "Content-Type: application/json"

curl -X PUT http://${COUCHDB_USER}:${COUCHDB_PASSWORD}@localhost:5984/_node/_local/_config/cors/origins \
     -d '"app://obsidian.md,capacitor://localhost,http://localhost"' \
     -H "Content-Type: application/json"

curl -X PUT http://${COUCHDB_USER}:${COUCHDB_PASSWORD}@localhost:5984/_node/_local/_config/cors/credentials \
     -d '"true"' \
     -H "Content-Type: application/json"

curl -X PUT http://${COUCHDB_USER}:${COUCHDB_PASSWORD}@localhost:5984/_node/_local/_config/cors/methods \
     -d '"GET, PUT, POST, HEAD, DELETE, OPTIONS"' \
     -H "Content-Type: application/json"

curl -X PUT http://${COUCHDB_USER}:${COUCHDB_PASSWORD}@localhost:5984/_node/_local/_config/cors/headers \
     -d '"accept, authorization, content-type, origin, referer, if-match, if-none-match, content-length"' \
     -H "Content-Type: application/json"

# Set maximum document size (for large attachments)
curl -X PUT http://${COUCHDB_USER}:${COUCHDB_PASSWORD}@localhost:5984/_node/_local/_config/httpd/max_http_request_size \
     -d '"4294967296"' \
     -H "Content-Type: application/json"

# Enable reduce limit
curl -X PUT http://${COUCHDB_USER}:${COUCHDB_PASSWORD}@localhost:5984/_node/_local/_config/query_server_config/reduce_limit \
     -d '"false"' \
     -H "Content-Type: application/json"

echo "CouchDB initialization completed"
