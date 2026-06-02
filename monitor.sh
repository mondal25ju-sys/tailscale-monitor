#!/bin/bash

# Tailscale Monitor - Device Monitoring Script
# Tracks device connection/disconnection events and sends Telegram notifications

set -euo pipefail

source ~/.tailscale-monitor.env

BASE="$HOME/tailscale-monitor"
CONFIG="$BASE/devices.conf"

mkdir -p "$BASE/data"

STATE="$BASE/data/state.json"
TIMEFILE="$BASE/data/time.json"
STATS="$BASE/data/stats.json"

NOW=$(date "+%Y-%m-%d %H:%M")
TS=$(date +%s)

CURRENT=$(tailscale status --json 2>/dev/null) || exit 0

[ ! -f "$STATE" ] && echo "$CURRENT" > "$STATE"
[ ! -f "$TIMEFILE" ] && echo "{}" > "$TIMEFILE"
[ ! -f "$STATS" ] && echo "{}" > "$STATS"

PREV=$(cat "$STATE")
TIMES=$(cat "$TIMEFILE")
USAGE=$(cat "$STATS")

SELF_DNS=$(jq -r '.Self.DNSName' <<< "$CURRENT")

get_device_info() {
    local LINE=$(grep "^$1|" "$CONFIG" 2>/dev/null)
    
    if [ -n "$LINE" ]; then
        DEV_NAME=$(echo "$LINE" | cut -d'|' -f2)
        USER_NAME=$(echo "$LINE" | cut -d'|' -f3)
    else
        DEV_NAME="Unknown Device"
        USER_NAME="Unknown User"
    fi
}

send() {
    local MSG="$1"
    
    curl -s -X POST \
        "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        --data-urlencode text="$MSG" >/dev/null
}

NOW_ON=$(jq -r '.Peer[] | select(.Online==true) | .DNSName' <<< "$CURRENT")
PREV_ON=$(jq -r '.Peer[] | select(.Online==true) | .DNSName' <<< "$PREV")

# CONNECTED DEVICES
for DNS in $NOW_ON; do
    if ! grep -qw "$DNS" <<< "$PREV_ON"; then
        IP=$(jq -r ".Peer[] | select(.DNSName==\"$DNS\") | .TailscaleIPs[0]" <<< "$CURRENT")
        
        get_device_info "$IP"
        
        TIMES=$(jq ". + {\"$DNS\":$TS}" <<< "$TIMES")
        
        send "[${NOW}] Device Connected

🟢 Status: ONLINE
📱 Device: $DEV_NAME
👤 User: $USER_NAME
🌐 IP: [REDACTED]
⏰ Time: $NOW"
    fi
done

# DISCONNECTED DEVICES
for DNS in $PREV_ON; do
    if ! grep -qw "$DNS" <<< "$NOW_ON"; then
        IP=$(jq -r ".Peer[] | select(.DNSName==\"$DNS\") | .TailscaleIPs[0]" <<< "$PREV")
        
        get_device_info "$IP"
        
        START=$(jq -r ".\"$DNS\"" <<< "$TIMES")
        
        if [ "$START" != "null" ]; then
            DUR=$((TS - START))
        else
            DUR=0
        fi
        
        USAGE=$(jq ". + {\"$USER_NAME\":((.\"$USER_NAME\" // 0)+$DUR)}" <<< "$USAGE")
        
        TIMES=$(jq "del(.\"$DNS\")" <<< "$TIMES")
        
        H=$((DUR/3600))
        M=$(((DUR%3600)/60))
        
        send "[${NOW}] Device Disconnected

🔴 Status: OFFLINE
💻 Device: $DEV_NAME
👤 User: $USER_NAME
🌐 IP: [REDACTED]
⌛️ Online Duration: ${H}h ${M}m"
    fi
done

echo "$CURRENT" > "$STATE"
echo "$TIMES" > "$TIMEFILE"
echo "$USAGE" > "$STATS"
