# Multi-stage using cached images
# Stage 1: Build with alpine
FROM alpine:latest AS build

WORKDIR /app

# Install Node.js and npm
RUN apk add --no-cache nodejs npm

# Copy package files
COPY package*.json ./

# Install dependencies (using npm install since we don't have package-lock.json)
RUN npm install --prefer-offline --no-audit --loglevel=error

# Copy source and build
COPY . .
ENV NODE_ENV=production
RUN npm run build

# Stage 2: Use cached nginx
FROM nginx:alpine

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built assets
COPY --from=build /app/dist /usr/share/nginx/html

# Add healthcheck
RUN echo 'OK' > /usr/share/nginx/html/healthz

# Setup nginx to run as non-root
RUN touch /var/run/nginx.pid && \
    mkdir -p /var/cache/nginx/client_temp \
             /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp \
             /var/cache/nginx/uwsgi_temp \
             /var/cache/nginx/scgi_temp && \
    chown -R nginx:nginx /var/run/nginx.pid && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /var/cache/nginx

USER nginx

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
