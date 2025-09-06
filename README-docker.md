# Self-Hosted Obsidian LiveSync on ARM64 Oracle Cloud

This Docker Compose setup allows you to self-host Obsidian LiveSync on an ARM64 Oracle Cloud server instance.

## Quick Start

1. **Clone and Setup**
   ```bash
   git clone <this-repo>
   cd obsidian-livesync
   ```

2. **Configure Environment**
   Edit the `.env` file:
   ```bash
   # Change these values
   COUCHDB_USER=your-username
   COUCHDB_PASSWORD=your-secure-password
   COUCHDB_SECRET=your-secret-key
   DOMAIN=your-domain.com
   ```

3. **Make Scripts Executable**
   ```bash
   chmod +x couchdb-init.sh
   ```

4. **Start Services**
   ```bash
   docker compose up -d
   ```

5. **Verify Setup**
   ```bash
   # Check if services are running
   docker compose ps
   
   # Check through reverse proxy (replace with your domain)
   curl -I https://your-domain.com/_up
   
   # Or check from inside the couchdb container (internal)
   docker compose exec couchdb curl -s http://localhost:5984/_all_dbs
   ```

## Services

- **CouchDB**: Database backend (internal port 5984, not public)
- **Nginx**: Reverse proxy with CORS support (ports 80/443)
- **LiveSync Plugin**: Optional plugin file server (port 8080)

## Oracle Cloud Setup

### 1. Security Groups / Firewall
Open these ports in your Oracle Cloud security list:
- Port 80 (HTTP)
- Port 443 (HTTPS)

Do not expose CouchDB (5984) publicly; access via the reverse proxy only.

### 2. Domain Setup
Point your domain to your Oracle Cloud instance IP:
```bash
# Example DNS record
A    your-domain.com    <your-oracle-cloud-ip>
```

### 3. SSL Certificates (Recommended)
For production, set up SSL certificates:

```bash
# Using Let's Encrypt with certbot
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.com

# Copy certificates
sudo mkdir -p ssl
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ssl/key.pem
sudo chown -R $USER:$USER ssl/

# Enable HTTPS in nginx.conf (uncomment the SSL server block)
# Then restart
docker compose restart nginx
```

## Obsidian Configuration

### Setup URI Generation
After starting the services, generate a setup URI:

1. Access CouchDB Fauxton interface: `https://your-domain.com/_utils`
2. Login with your credentials
3. Create a new database for your vault
4. Use the setup wizard in Obsidian LiveSync plugin

### Manual Setup
In Obsidian LiveSync settings:
- **Remote Database**: `http://your-domain.com` (or `https://` if SSL enabled)
- **Username**: Your CouchDB username
- **Password**: Your CouchDB password
- **Database**: Your database name

## Maintenance

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f couchdb
docker compose logs -f nginx
```

### Backup Database
```bash
# Backup CouchDB data
docker compose exec couchdb couchdb-backup

# Or backup the volume
docker run --rm -v obsidian-livesync_couchdb_data:/data -v $(pwd):/backup alpine tar czf /backup/couchdb-backup.tar.gz -C /data .
```

### Update
```bash
# Pull latest images
docker compose pull

# Restart with new images
docker compose up -d
```

## Security Notes

1. **Change default passwords** in `.env`
2. **Use HTTPS** in production
3. **Restrict access** with firewall rules
4. **Regular backups** of your CouchDB data
5. **Monitor logs** for suspicious activity

## Troubleshooting

### CouchDB Connection Issues
```bash
# Check CouchDB logs
docker compose logs couchdb

# Test CouchDB through reverse proxy
curl -I https://your-domain.com/_up

# Or from inside the container (internal)
docker compose exec couchdb curl -s http://localhost:5984/_all_dbs
```

### CORS Issues
The nginx configuration includes CORS headers for Obsidian. If you still have issues:
1. Check nginx logs: `docker compose logs nginx`
2. Verify CORS settings in CouchDB Fauxton
3. Test with browser dev tools

### ARM64 Build Issues
If building fails on ARM64:
```bash
# Build manually
docker build --platform linux/arm64 -t obsidian-livesync .

# Or pull pre-built image (if available)
docker pull your-registry/obsidian-livesync:arm64
```

## Performance Tuning

For better performance on Oracle Cloud:
1. **Increase CouchDB memory**: Add `COUCHDB_ERLANG_OPTS=+MHms 2048` to environment
2. **Tune Oracle Cloud instance**: Use compute optimized shapes if available
3. **Monitor disk I/O**: CouchDB can be I/O intensive

## Support

- [Obsidian LiveSync Documentation](https://github.com/vrtmrz/obsidian-livesync)
- [CouchDB Documentation](https://docs.couchdb.org/)
- [Oracle Cloud Documentation](https://docs.oracle.com/en-us/iaas/)
