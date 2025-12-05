# OpenTAKServer UI Docker Image
# Builds the React UI and serves it with nginx
# Built for ARM64 (Raspberry Pi 5)

FROM node:20-alpine AS builder

# Clone and build UI at specific commit/tag
# Update the branch/tag to control version
ARG UI_VERSION=master

WORKDIR /build

RUN apk add --no-cache git && \
    git clone --depth 1 --branch ${UI_VERSION} https://github.com/brian7704/OpenTAKServer-UI.git . && \
    npm install --legacy-peer-deps && \
    npm run build

# Production stage
FROM nginx:alpine

# Copy built UI
COPY --from=builder /build/dist /usr/share/nginx/html

# Copy nginx configuration (will be overridden by ConfigMap in k8s)
# This is just for standalone docker usage
RUN echo 'server { \
    listen 8080; \
    location / { \
        root /usr/share/nginx/html; \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
