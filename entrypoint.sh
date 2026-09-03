#!/bin/bash

set -e

echo
echo "=============================================="
echo " Railway Ubuntu Desktop + Xray"
echo "=============================================="
echo

XRAY_BIN="/usr/local/bin/xray"
XRAY_CONFIG="/etc/xray/config.json"

XRAY_PORT=10000
NGINX_PORT=8080
NOVNC_PORT=6080
XRAY_PATH="/xray"

# ---------------------------------------------------------
# UUID
# ---------------------------------------------------------

if [ -z "${XRAY_UUID}" ]; then
    XRAY_UUID=$(${XRAY_BIN} uuid)
fi

echo "[+] Xray UUID:"
echo "${XRAY_UUID}"
echo

# ---------------------------------------------------------
# Railway Domain
# ---------------------------------------------------------

RAILWAY_DOMAIN="${RAILWAY_PUBLIC_DOMAIN}"

if [ -z "${RAILWAY_DOMAIN}" ]; then
    echo "[!] RAILWAY_PUBLIC_DOMAIN is not available yet."
    echo "[!] Railway domain must be generated after deployment."
else
    echo "[+] Railway Public Domain:"
    echo "${RAILWAY_DOMAIN}"
fi

# ---------------------------------------------------------
# Generate Xray config
# ---------------------------------------------------------

cat > "${XRAY_CONFIG}" <<EOF
{
  "log": {
    "loglevel": "warning"
  },

  "inbounds": [
    {
      "tag": "vless-xhttp",
      "listen": "127.0.0.1",
      "port": ${XRAY_PORT},
      "protocol": "vless",

      "settings": {
        "users": [
          {
            "id": "${XRAY_UUID}",
            "level": 0
          }
        ],
        "decryption": "none"
      },

      "streamSettings": {
        "network": "xhttp",
        "security": "none",

        "xhttpSettings": {
          "path": "${XRAY_PATH}"
        }
      }
    }
  ],

  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    },

    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ]
}
EOF

# ---------------------------------------------------------
# Validate Xray configuration
# ---------------------------------------------------------

echo "[+] Checking Xray configuration..."

${XRAY_BIN} run -test -config "${XRAY_CONFIG}"

echo "[+] Xray configuration OK."
echo

# ---------------------------------------------------------
# Stop old processes if any
# ---------------------------------------------------------

pkill -f "xray run" || true
pkill -f "websockify" || true
pkill -f "vncserver" || true
pkill -f "nginx" || true

# ---------------------------------------------------------
# Start Xray
# ---------------------------------------------------------

echo "[+] Starting Xray..."

${XRAY_BIN} run -config "${XRAY_CONFIG}" \
    > /var/log/xray.log 2>&1 &

XRAY_PID=$!

sleep 2

if ! kill -0 "${XRAY_PID}" 2>/dev/null; then
    echo "[ERROR] Xray failed to start."
    cat /var/log/xray.log
    exit 1
fi

echo "[+] Xray started."
echo "[+] PID: ${XRAY_PID}"
echo

# ---------------------------------------------------------
# Start VNC
# ---------------------------------------------------------

echo "[+] Starting VNC..."

rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1

vncserver :1 \
    -localhost yes \
    -SecurityTypes None \
    -geometry 1024x768 \
    -depth 24

echo "[+] VNC started on localhost:5901"
echo

# ---------------------------------------------------------
# Start noVNC
# ---------------------------------------------------------

echo "[+] Starting noVNC..."

websockify \
    --web=/usr/share/novnc/ \
    127.0.0.1:${NOVNC_PORT} \
    127.0.0.1:5901 \
    > /var/log/novnc.log 2>&1 &

NOVNC_PID=$!

sleep 2

if ! kill -0 "${NOVNC_PID}" 2>/dev/null; then
    echo "[ERROR] noVNC failed to start."
    cat /var/log/novnc.log
    exit 1
fi

echo "[+] noVNC started."
echo "[+] Internal noVNC: ${NOVNC_PORT}"
echo

# ---------------------------------------------------------
# Start Nginx
# ---------------------------------------------------------

echo "[+] Starting Nginx..."

nginx -t

nginx -g "daemon off;" &
NGINX_PID=$!

sleep 2

if ! kill -0 "${NGINX_PID}" 2>/dev/null; then
    echo "[ERROR] Nginx failed to start."
    exit 1
fi

echo "[+] Nginx started."
echo

# ---------------------------------------------------------
# Generate VLESS URI
# ---------------------------------------------------------

if [ -n "${RAILWAY_DOMAIN}" ]; then

    VLESS_URI="vless://${XRAY_UUID}@${RAILWAY_DOMAIN}:443?encryption=none&security=tls&type=xhttp&path=%2Fxray&host=${RAILWAY_DOMAIN}&sni=${RAILWAY_DOMAIN}#Railway-XHTTP"

    echo
    echo "=============================================="
    echo "              CONNECTION INFO"
    echo "=============================================="
    echo
    echo "Domain:"
    echo "${RAILWAY_DOMAIN}"
    echo
    echo "Public Port:"
    echo "443"
    echo
    echo "Internal Nginx Port:"
    echo "8080"
    echo
    echo "Internal Xray Port:"
    echo "10000"
    echo
    echo "Internal noVNC Port:"
    echo "6080"
    echo
    echo "UUID:"
    echo "${XRAY_UUID}"
    echo
    echo "Xray Path:"
    echo "${XRAY_PATH}"
    echo
    echo "Desktop:"
    echo "https://${RAILWAY_DOMAIN}/"
    echo
    echo "VLESS:"
    echo "${VLESS_URI}"
    echo
    echo "=============================================="
    echo
else

    echo
    echo "=============================================="
    echo "Railway domain not available yet."
    echo "=============================================="
    echo
    echo "UUID:"
    echo "${XRAY_UUID}"
    echo
fi

# ---------------------------------------------------------
# Monitor processes
# ---------------------------------------------------------

while true; do

    if ! kill -0 "${XRAY_PID}" 2>/dev/null; then
        echo "[ERROR] Xray stopped!"
        tail -50 /var/log/xray.log
        exit 1
    fi

    if ! kill -0 "${NGINX_PID}" 2>/dev/null; then
        echo "[ERROR] Nginx stopped!"
        exit 1
    fi

    if ! kill -0 "${NOVNC_PID}" 2>/dev/null; then
        echo "[ERROR] noVNC stopped!"
        exit 1
    fi

    sleep 10

done
