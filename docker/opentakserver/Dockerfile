# OpenTAKServer Docker Image
# Builds a stable, production-ready image with all dependencies pre-installed
# Built for ARM64 (Raspberry Pi 5)

FROM python:3.12-slim

# Set version - update this when you want to upgrade
ARG OTS_VERSION=1.6.3

# Install system dependencies and build tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ffmpeg \
    curl \
    ca-certificates \
    gcc \
    g++ \
    python3-dev \
    libpq-dev \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Install OpenTAKServer at specific version
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir opentakserver==${OTS_VERSION}

# Patch Socket.IO to work properly in K8s environment
# 1. Remove RabbitMQ message_queue (doesn't work across pod restarts)
# 2. Add CORS configuration (allow all origins for nginx proxy)
RUN python3 <<'PATCHEOF'
import re, glob

site_packages = glob.glob("/usr/local/lib/python*/site-packages")[0]

# Patch extensions.py to add CORS
extensions_file = f"{site_packages}/opentakserver/extensions.py"
with open(extensions_file, "r") as f:
    content = f.read()

# Replace the SocketIO initialization
old_line = "socketio = SocketIO(async_mode='gevent')"
new_line = "socketio = SocketIO(async_mode='gevent', cors_allowed_origins='*', logger=False, engineio_logger=False)"
content = content.replace(old_line, new_line)

with open(extensions_file, "w") as f:
    f.write(content)

# Patch app.py to remove message_queue and increase timeout
app_file = f"{site_packages}/opentakserver/app.py"
with open(app_file, "r") as f:
    content = f.read()

# Remove message_queue and set timeout to 60
pattern = r'socketio\.init_app\(app, logger=socketio_logger, ping_timeout=1, message_queue="amqp://" \+ app\.config\.get\("OTS_RABBITMQ_SERVER_ADDRESS"\)\)'
replacement = 'socketio.init_app(app, logger=socketio_logger, ping_timeout=60)'
content = re.sub(pattern, replacement, content)

with open(app_file, "w") as f:
    f.write(content)

print(f"Socket.IO patched in {site_packages}:")
print("  ✓ CORS enabled (cors_allowed_origins='*')")
print("  ✓ message_queue removed")
print("  ✓ ping_timeout increased to 60")
PATCHEOF

# Remove build tools to reduce image size (keep libpq5 for runtime)
RUN apt-get remove -y gcc g++ python3-dev libpq-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Create data directory
RUN mkdir -p /home/ots/ots

# Set working directory
WORKDIR /home/ots

# Expose ports
EXPOSE 8081 8088 8089

# Default environment
ENV HOME=/home/ots

# Start OpenTAKServer
CMD ["opentakserver"]
