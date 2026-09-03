#!/bin/bash

set -e


# =========================================================
# Variables
# =========================================================

XRAY_BIN="/usr/local/bin/xray"

XRAY_CONFIG="/etc/xray/config.json"

XRAY_PORT=10000

NOVNC_PORT=6080

APP_PORT="${PORT:-8080}"

XRAY_PATH="${XRAY_PATH:-/xray}"

VNC_GEOMETRY="${VNC_GEOMETRY:-1280x800}"

RAILWAY_DOMAIN="${RAILWAY_PUBLIC_DOMAIN:-}"


# =========================================================
# Start message
# =========================================================

echo ""
echo "=================================================="
echo " Railway Ubuntu Desktop + Xray"
echo "=================================================="
echo ""

echo "[INFO] Railway APP PORT: ${APP_PORT}"

echo "[INFO] Xray internal port: ${XRAY_PORT}"

echo "[INFO] noVNC internal port: ${NOVNC_PORT}"

echo "[INFO] XHTTP path: ${XRAY_PATH}"

echo ""


# =========================================================
# Generate UUID
# =========================================================

if [ -z "${XRAY_UUID:-}" ]; then

    XRAY_UUID=$(${XRAY_BIN} uuid)

fi


echo "[INFO] XRAY UUID:"

echo "${XRAY_UUID}"

echo ""


# =========================================================
# Generate Xray configuration
# =========================================================

mkdir -p /etc/xray

cat > "${XRAY_CONFIG}" <<EOF
{
  "log": {
    "loglevel": "info"
  },

  "inbounds": [
    {
      "tag": "vless-xhttp",

      "listen": "127.0.0.1",

      "port": ${XRAY_PORT},

      "protocol": "vless",

      "settings": {
        "clients": [
          {
            "id": "${XRAY_UUID}",
            "email": "railway-user",
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
      "protocol": "freedom",
      "tag": "direct"
    },

    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF


# =========================================================
# Test Xray configuration
# =========================================================

echo "[INFO] Testing Xray configuration..."

if ! ${XRAY_BIN} run -test -config "${XRAY_CONFIG}"; then

    echo "[ERROR] Xray configuration is invalid."

    cat "${XRAY_CONFIG}"

    exit 1

fi


echo "[OK] Xray configuration is valid."

echo ""


# =========================================================
# Start Xray
# =========================================================

echo "[INFO] Starting Xray..."

${XRAY_BIN} run -config "${XRAY_CONFIG}" \
    > /var/log/xray/xray.log 2>&1 &

XRAY_PID=$!


sleep 2


if ! kill -0 "${XRAY_PID}" 2>/dev/null; then

    echo "[ERROR] Xray failed to start."

    cat /var/log/xray/xray.log || true

    exit 1

fi


echo "[OK] Xray started."

echo "[INFO] Xray PID: ${XRAY_PID}"

echo ""


# =========================================================
# Prepare VNC
# =========================================================

echo "[INFO] Preparing XFCE..."

mkdir -p /root/.vnc


cat > /root/.vnc/xstartup <<'EOF'
#!/bin/sh

unset SESSION_MANAGER

unset DBUS_SESSION_BUS_ADDRESS

export XDG_CURRENT_DESKTOP=XFCE

export XDG_SESSION_DESKTOP=xfce

exec dbus-launch --exit-with-session startxfce4
EOF


chmod +x /root/.vnc/xstartup


# Remove stale VNC files
rm -f /tmp/.X1-lock

rm -f /tmp/.X11-unix/X1

rm -f /root/.vnc/*.pid


# =========================================================
# Start VNC
# =========================================================

echo "[INFO] Starting VNC..."

vncserver :1 \
    -geometry "${VNC_GEOMETRY}" \
    -depth 24 \
    -localhost yes \
    -SecurityTypes None \
    --I-KNOW-THIS-IS-INSECURE


echo "[OK] VNC started on 127.0.0.1:5901"

echo ""


# =========================================================
# Start noVNC
# =========================================================

echo "[INFO] Starting noVNC..."

websockify \
    --web=/usr/share/novnc/ \
    127.0.0.1:${NOVNC_PORT} \
    127.0.0.1:5901 \
    > /var/log/novnc.log 2>&1 &


NOVNC_PID=$!


sleep 2


if ! kill -0 "${NOVNC_PID}" 2>/dev/null; then

    echo "[ERROR] noVNC failed to start."

    cat /var/log/novnc.log || true

    exit 1

fi


echo "[OK] noVNC started."

echo "[INFO] noVNC address: 127.0.0.1:${NOVNC_PORT}"

echo ""


# =========================================================
# Generate Nginx configuration using Railway PORT
# =========================================================

echo "[INFO] Configuring Nginx..."

sed "s/__PORT__/${APP_PORT}/g" \
    /etc/nginx/nginx.conf.template \
    > /etc/nginx/nginx.conf


echo "[INFO] Nginx will listen on: ${APP_PORT}"

echo ""


# =========================================================
# Test Nginx
# =========================================================

echo "[INFO] Testing Nginx configuration..."

nginx -t


echo "[OK] Nginx configuration is valid."

echo ""


# =========================================================
# Start Nginx
# =========================================================

echo "[INFO] Starting Nginx..."

nginx -g "daemon off;" &


NGINX_PID=$!


sleep 2


if ! kill -0 "${NGINX_PID}" 2>/dev/null; then

    echo "[ERROR] Nginx failed to start."

    exit 1

fi


echo "[OK] Nginx started."

echo "[INFO] Public application port: ${APP_PORT}"

echo ""


# =========================================================
# Railway Domain
# =========================================================

echo "=================================================="
echo "             RAILWAY CONNECTION INFO"
echo "=================================================="

echo ""

if [ -n "${RAILWAY_DOMAIN}" ]; then

    echo "Railway Domain:"

    echo "${RAILWAY_DOMAIN}"

    echo ""

    echo "Desktop URL:"

    echo "https://${RAILWAY_DOMAIN}/"

    echo ""

    echo "Healthcheck URL:"

    echo "https://${RAILWAY_DOMAIN}/health"

    echo ""

else

    echo "[WARNING] RAILWAY_PUBLIC_DOMAIN is not available."

    echo ""

fi


# =========================================================
# Generate VLESS Link
# =========================================================

if [ -n "${RAILWAY_DOMAIN}" ]; then

    VLESS_LINK="vless://${XRAY_UUID}@${RAILWAY_DOMAIN}:443?encryption=none&security=tls&type=xhttp&path=%2Fxray&host=${RAILWAY_DOMAIN}&sni=${RAILWAY_DOMAIN}#Railway-XHTTP"

    echo "=================================================="

    echo "                 VLESS CONFIG"

    echo "=================================================="

    echo ""

    echo "${VLESS_LINK}"

    echo ""

fi


# =========================================================
# Internal information
# =========================================================

echo "=================================================="

echo "             INTERNAL SERVICES"

echo "=================================================="

echo ""

echo "Railway application port: ${APP_PORT}"

echo ""

echo "Nginx:"

echo "127.0.0.1:${APP_PORT}"

echo ""

echo "Xray:"

echo "127.0.0.1:${XRAY_PORT}"

echo ""

echo "noVNC:"

echo "127.0.0.1:${NOVNC_PORT}"

echo ""

echo "VNC:"

echo "127.0.0.1:5901"

echo ""

echo "=================================================="

echo ""

echo "[OK] All services started."

echo ""


# =========================================================
# Process monitoring
# =========================================================

while true; do

    if ! kill -0 "${XRAY_PID}" 2>/dev/null; then

        echo "[ERROR] Xray stopped."

        cat /var/log/xray/xray.log || true

        exit 1

    fi


    if ! kill -0 "${NOVNC_PID}" 2>/dev/null; then

        echo "[ERROR] noVNC stopped."

        cat /var/log/novnc.log || true

        exit 1

    fi


    if ! kill -0 "${NGINX_PID}" 2>/dev/null; then

        echo "[ERROR] Nginx stopped."

        exit 1

    fi


    sleep 10

done
