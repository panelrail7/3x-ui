FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# نسخه Xray
ARG XRAY_VERSION=26.7.28

# =========================================================
# Install packages
# =========================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    novnc \
    websockify \
    nginx \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    x11-apps \
    xterm \
    xubuntu-icon-theme \
    ca-certificates \
    curl \
    wget \
    unzip \
    openssl \
    python3 \
    procps \
    net-tools \
    iproute2 \
    iputils-ping \
    tzdata \
    sudo \
    git \
    vim \
    && rm -rf /var/lib/apt/lists/*


# =========================================================
# Install Xray
# =========================================================

RUN set -eux; \
    wget -q \
      "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip" \
      -O /tmp/xray.zip; \
    mkdir -p /tmp/xray; \
    unzip -q /tmp/xray.zip -d /tmp/xray; \
    install -m 0755 /tmp/xray/xray /usr/local/bin/xray; \
    mkdir -p /etc/xray /var/log/xray /usr/local/share/xray; \
    if [ -f /tmp/xray/geoip.dat ]; then \
        cp /tmp/xray/geoip.dat /usr/local/share/xray/; \
    fi; \
    if [ -f /tmp/xray/geosite.dat ]; then \
        cp /tmp/xray/geosite.dat /usr/local/share/xray/; \
    fi; \
    rm -rf /tmp/xray /tmp/xray.zip


# =========================================================
# Verify Xray
# =========================================================

RUN /usr/local/bin/xray version


# =========================================================
# Prepare VNC
# =========================================================

RUN mkdir -p /root/.vnc \
    /etc/xray \
    /var/log/xray \
    /var/log/nginx \
    && touch /root/.Xauthority


# =========================================================
# Copy files
# =========================================================

COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY xray-config.json /etc/xray/config.json
COPY entrypoint.sh /entrypoint.sh


# =========================================================
# Permissions
# =========================================================

RUN chmod +x /entrypoint.sh


# =========================================================
# Railway
# =========================================================

EXPOSE 8080


# =========================================================
# Start
# =========================================================

ENTRYPOINT ["/entrypoint.sh"]
