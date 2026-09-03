FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

ARG XRAY_VERSION=26.7.28

RUN apt-get update && apt-get install --no-install-recommends -y \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    novnc \
    websockify \
    nginx \
    sudo \
    xterm \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    x11-apps \
    xubuntu-icon-theme \
    openssl \
    ca-certificates \
    curl \
    wget \
    git \
    vim \
    net-tools \
    iproute2 \
    iputils-ping \
    procps \
    python3 \
    unzip \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# Xray
# ---------------------------------------------------------

RUN mkdir -p /usr/local/bin /etc/xray

RUN wget -q \
    "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip" \
    -O /tmp/xray.zip \
    && unzip -o /tmp/xray.zip -d /tmp/xray \
    && install -m 0755 /tmp/xray/xray /usr/local/bin/xray \
    && rm -rf /tmp/xray /tmp/xray.zip

RUN /usr/local/bin/xray version

# ---------------------------------------------------------
# XFCE / VNC
# ---------------------------------------------------------

RUN mkdir -p /root/.vnc \
    && touch /root/.Xauthority

RUN printf '#!/bin/sh\n\
unset SESSION_MANAGER\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
export XDG_CURRENT_DESKTOP=XFCE\n\
export XDG_CONFIG_DIRS=/etc/xdg/xdg-xubuntu:/etc/xdg/xdg-xfce:/etc/xdg:/etc/xdg\n\
dbus-launch --exit-with-session startxfce4 &\n' \
> /root/.vnc/xstartup

RUN chmod +x /root/.vnc/xstartup

# ---------------------------------------------------------
# Config files
# ---------------------------------------------------------

COPY nginx.conf /etc/nginx/nginx.conf
COPY xray-config.json /etc/xray/config.json
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

# Railway will expose HTTP/HTTPS through the public domain.
# Internal application listener:
EXPOSE 8080

CMD ["/entrypoint.sh"]
