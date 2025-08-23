# Multi-stage build for Obsidian LiveSync plugin
FROM --platform=linux/arm64 node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./
COPY esbuild.config.mjs ./
COPY .prettierrc ./

# Install dependencies
RUN npm ci

# Copy source code
COPY src/ ./src/
COPY docs/ ./docs/

# Build the plugin
RUN npm run build

# Production stage - serve built plugin files
FROM --platform=linux/arm64 nginx:alpine

# Copy built plugin files
COPY --from=builder /app/main.js /usr/share/nginx/html/
COPY --from=builder /app/manifest.json /usr/share/nginx/html/
COPY --from=builder /app/styles.css /usr/share/nginx/html/

# Copy custom nginx configuration
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name localhost;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files \$uri \$uri/ =404;
        
        # Enable CORS for Obsidian
        add_header 'Access-Control-Allow-Origin' 'app://obsidian.md' always;
        add_header 'Access-Control-Allow-Origin' 'capacitor://localhost' always;
        add_header 'Access-Control-Allow-Origin' 'http://localhost' always;
        add_header 'Access-Control-Allow-Methods' 'GET, PUT, POST, HEAD, DELETE' always;
        add_header 'Access-Control-Allow-Headers' 'accept,authorization,content-type,origin,referer' always;
        add_header 'Access-Control-Allow-Credentials' 'true' always;
        add_header 'Access-Control-Max-Age' '3600' always;
        add_header 'Vary' 'Origin' always;
    }
}
EOF

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]