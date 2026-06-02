#!/bin/bash

# Tailscale Monitor - Advanced Alert System
# Telegram-only notifications for 12+ alert types

set -euo pipefail

source ~/.tailscale-monitor.env

BASE="$HOME/tailscale-monitor"
CONFIG="$BASE/devices.conf"
DATA="$BASE/data"
LOGS="$BASE/logs"
ALERTS_STATE="$DATA/alerts_state.json"

mkdir -p "$LOGS" "$DATA"

# ===== ALERT THRESHOLDS =====
HIGH_USAGE_HOURS=18
CRITICAL_USAGE_HOURS=22
OFFLINE_TIMEOUT_HOURS=24
CRITICAL_OFFLINE_HOURS=72
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=85

LOG_FILE="$LOGS/alerts_$(date +%Y-%m-%d).log"

log() {
    local LEVEL="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$LEVEL] $*" | tee -a "$LOG_FILE"
}

init_state() {
    [ ! -f "$ALERTS_STATE" ] && echo "{\"last_alerts\":{}}" > "$ALERTS_STATE"
}

get_last_alert() {
    local ALERT_ID="$1"
    jq -r ".last_alerts.\"$ALERT_ID\" // 0" "$ALERTS_STATE" 2>/dev/null || echo 0
}

set_last_alert() {
    local ALERT_ID="$1"
    local TIMESTAMP=$(date +%s)
    
    local STATE=$(cat "$ALERTS_STATE")
    STATE=$(echo "$STATE" | jq ".last_alerts.\"$ALERT_ID\" = $TIMESTAMP")
    echo "$STATE" > "$ALERTS_STATE"
}

should_alert() {
    local ALERT_ID="$1"
    local MIN_INTERVAL="${2:-300}"
    
    local LAST=$(get_last_alert "$ALERT_ID")
    local NOW=$(date +%s)
    local DIFF=$((NOW - LAST))
    
    [ "$DIFF" -ge "$MIN_INTERVAL" ]
}

send_alert() {
    local MSG="$1"
    local SEVERITY="${2:-info}"
    
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        log "ERROR" "BOT_TOKEN or CHAT_ID not configured"
        return 1
    fi
    
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d parse_mode="Markdown" \
        --data-urlencode text="$MSG" >/dev/null
    
    log "INFO" "Alert sent"
}

get_device_info() {
    local IP="$1"
    local LINE=$(grep "^$IP|" "$CONFIG" 2>/dev/null || echo "")
    
    if [ -n "$LINE" ]; then
        echo "$LINE" | cut -d'|' -f2,3 | tr '|' ':'
    else
        echo "Unknown:Unknown"
    fi
}

alert_device_connected() {
    log "INFO" "Checking connected devices..."
    
    local CURRENT=$(tailscale status --json 2>/dev/null)
    local ONLINE=$(echo "$CURRENT" | jq '[.Peer[] | select(.Online==true)] | length')
    
    if [ "$ONLINE" -gt 0 ]; then
        local ALERT_ID="devices_online"
        if should_alert "$ALERT_ID" 300; then
            send_alert "✅ Devices Online: $ONLINE" "success"
            set_last_alert "$ALERT_ID"
        fi
    fi
}

alert_device_disconnected() {
    log "INFO" "Checking offline devices..."
    
    local CURRENT=$(tailscale status --json 2>/dev/null)
    local OFFLINE=$(echo "$CURRENT" | jq '[.Peer[] | select(.Online==false)] | length')
    
    if [ "$OFFLINE" -gt 0 ]; then
        local ALERT_ID="devices_offline_${OFFLINE}"
        if should_alert "$ALERT_ID" 3600; then
            send_alert "❌ Devices Offline: $OFFLINE" "warning"
            set_last_alert "$ALERT_ID"
        fi
    fi
}

alert_high_daily_usage() {
    log "INFO" "Checking daily usage..."
    
    local STATS="$DATA/stats.json"
    [ ! -f "$STATS" ] && return
    
    while IFS="|" read -r USER TIME; do
        local HOURS=$((TIME / 3600))
        
        if [ "$HOURS" -gt "$CRITICAL_USAGE_HOURS" ]; then
            local ALERT_ID="critical_usage_$USER"
            if should_alert "$ALERT_ID" 3600; then
                send_alert "🚨 CRITICAL: $USER online ${HOURS}h (>$CRITICAL_USAGE_HOURS)" "critical"
                set_last_alert "$ALERT_ID"
            fi
        elif [ "$HOURS" -gt "$HIGH_USAGE_HOURS" ]; then
            local ALERT_ID="warning_usage_$USER"
            if should_alert "$ALERT_ID" 1800; then
                send_alert "⚠️ High Usage: $USER online ${HOURS}h (>$HIGH_USAGE_HOURS)" "warning"
                set_last_alert "$ALERT_ID"
            fi
        fi
    done < <(jq -r 'to_entries[] | "\(.key)|\(.value)"' "$STATS" 2>/dev/null || echo "")
}

alert_all_offline() {
    log "INFO" "Checking if all devices offline..."
    
    local CURRENT=$(tailscale status --json 2>/dev/null)
    local ONLINE=$(echo "$CURRENT" | jq '[.Peer[] | select(.Online==true)] | length')
    
    if [ "$ONLINE" -eq 0 ]; then
        local ALERT_ID="all_offline"
        if should_alert "$ALERT_ID" 1800; then
            send_alert "🚨 CRITICAL: ALL DEVICES OFFLINE" "critical"
            set_last_alert "$ALERT_ID"
        fi
    fi
}

alert_cpu_high() {
    log "INFO" "Checking CPU..."
    
    local CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' || echo 0)
    local CPU_INT=$(printf "%.0f" "$CPU")
    
    if [ "$CPU_INT" -gt "$CPU_THRESHOLD" ]; then
        local ALERT_ID="cpu_high"
        if should_alert "$ALERT_ID" 600; then
            send_alert "⚠️ High CPU: ${CPU_INT}% (threshold: ${CPU_THRESHOLD}%)" "warning"
            set_last_alert "$ALERT_ID"
        fi
    fi
}

alert_memory_high() {
    log "INFO" "Checking memory..."
    
    local MEM=$(free 2>/dev/null | grep Mem | awk '{print int($3/$2 * 100)}' || echo 0)
    
    if [ "$MEM" -gt "$MEMORY_THRESHOLD" ]; then
        local ALERT_ID="memory_high"
        if should_alert "$ALERT_ID" 600; then
            send_alert "⚠️ High Memory: ${MEM}% (threshold: ${MEMORY_THRESHOLD}%)" "warning"
            set_last_alert "$ALERT_ID"
        fi
    fi
}

alert_disk_low() {
    log "INFO" "Checking disk..."
    
    local DISK=$(df / 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' || echo 0)
    
    if [ "$DISK" -gt "$DISK_THRESHOLD" ]; then
        local ALERT_ID="disk_low"
        if should_alert "$ALERT_ID" 3600; then
            send_alert "⚠️ Low Disk: ${DISK}% (threshold: ${DISK_THRESHOLD}%)" "warning"
            set_last_alert "$ALERT_ID"
        fi
    fi
}

alert_server_down() {
    log "INFO" "Checking server..."
    
    if ! tailscale status >/dev/null 2>&1; then
        local ALERT_ID="server_down"
        if should_alert "$ALERT_ID" 300; then
            send_alert "🚨 CRITICAL: Tailscale Server Unreachable" "critical"
            set_last_alert "$ALERT_ID"
        fi
    fi
}

main() {
    local ALERT_TYPE="${1:-all}"
    
    init_state
    log "INFO" "Starting alert check: $ALERT_TYPE"
    
    case "$ALERT_TYPE" in
        all)
            alert_device_connected
            alert_device_disconnected
            alert_high_daily_usage
            alert_all_offline
            alert_cpu_high
            alert_memory_high
            alert_disk_low
            alert_server_down
            ;;
        devices)
            alert_device_connected
            alert_device_disconnected
            alert_all_offline
            ;;
        usage)
            alert_high_daily_usage
            ;;
        system)
            alert_cpu_high
            alert_memory_high
            alert_disk_low
            ;;
        server)
            alert_server_down
            ;;
        *)
            log "ERROR" "Unknown alert type: $ALERT_TYPE"
            exit 1
            ;;
    esac
    
    log "INFO" "Alert check completed"
}

main "$@"
