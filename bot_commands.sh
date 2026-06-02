#!/bin/bash

# Tailscale Monitor - Bot Commands Handler
# Processes Telegram commands and returns real-time system information

set -euo pipefail

source ~/.tailscale-monitor.env

BASE="/home/$USER/tailscale-monitor/data"
CONFIG="/home/$USER/tailscale-monitor/devices.conf"
LOGS="/home/$USER/tailscale-monitor/logs"

STATS="$BASE/stats.json"
TIME_FILE="$BASE/time.json"
MONTHLY="$BASE/monthly.json"

mkdir -p "$LOGS"

LOG_FILE="$LOGS/bot_commands_$(date +%Y-%m-%d).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_device_name() {
    local IP="$1"
    local LINE=$(grep "^$IP|" "$CONFIG" 2>/dev/null || echo "")
    
    if [ -n "$LINE" ]; then
        echo "$LINE" | cut -d'|' -f2 | xargs
    else
        echo "[DEVICE_NAME]"
    fi
}

get_user_name() {
    local IP="$1"
    local LINE=$(grep "^$IP|" "$CONFIG" 2>/dev/null || echo "")
    
    if [ -n "$LINE" ]; then
        echo "$LINE" | cut -d'|' -f3 | xargs
    else
        echo "[USER_NAME]"
    fi
}

send_telegram() {
    local MSG="$1"
    
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d parse_mode="Markdown" \
        --data-urlencode text="$MSG" >/dev/null
    
    log "Message sent"
}

# COMMAND: STATUS
cmd_status() {
    log "Executing: /status"
    
    local CURRENT=$(tailscale status --json 2>/dev/null)
    local ONLINE=$(echo "$CURRENT" | jq '.Peer[] | select(.Online==true)' | jq -s 'length')
    local TOTAL=$(echo "$CURRENT" | jq '.Peer | length')
    local SELF_DNS=$(echo "$CURRENT" | jq -r '.Self.DNSName')
    
    local MSG="🟢 *Tailscale Status*"$'\n\n'
    MSG+="*Server:* $SELF_DNS"$'\n'
    MSG+="*Online Devices:* $ONLINE/$TOTAL"$'\n'
    MSG+="*Updated:* $(date '+%Y-%m-%d %H:%M')"
    
    send_telegram "$MSG"
}

# COMMAND: ONLINE DEVICES
cmd_online() {
    log "Executing: /online"
    
    local CURRENT=$(tailscale status --json 2>/dev/null)
    local MSG="🟢 *Online Devices*"$'\n\n'
    local COUNT=0
    
    while IFS= read -r peer; do
        local IP=$(echo "$peer" | jq -r '.TailscaleIPs[0]')
        local DNS=$(echo "$peer" | jq -r '.DNSName')
        local DEV_NAME=$(get_device_name "$IP")
        local USER=$(get_user_name "$IP")
        
        MSG+="✅ *$DEV_NAME*"$'\n'
        MSG+="   👤 $USER"$'\n\n'
        
        COUNT=$((COUNT + 1))
    done < <(echo "$CURRENT" | jq -c '.Peer[] | select(.Online==true)')
    
    MSG+="📊 *Total Online:* $COUNT"
    
    send_telegram "$MSG"
}

# COMMAND: OFFLINE DEVICES
cmd_offline() {
    log "Executing: /offline"
    
    local CURRENT=$(tailscale status --json 2>/dev/null)
    local MSG="🔴 *Offline Devices*"$'\n\n'
    local COUNT=0
    
    while IFS= read -r peer; do
        local IP=$(echo "$peer" | jq -r '.TailscaleIPs[0]')
        local DEV_NAME=$(get_device_name "$IP")
        local USER=$(get_user_name "$IP")
        
        MSG+="❌ *$DEV_NAME*"$'\n'
        MSG+="   👤 $USER"$'\n\n'
        
        COUNT=$((COUNT + 1))
    done < <(echo "$CURRENT" | jq -c '.Peer[] | select(.Online==false)')
    
    MSG+="📊 *Total Offline:* $COUNT"
    
    send_telegram "$MSG"
}

# COMMAND: TODAY'S STATISTICS
cmd_stats() {
    log "Executing: /stats"
    
    if [ ! -s "$STATS" ] || [ "$(cat "$STATS")" = "{}" ]; then
        send_telegram "📊 No statistics recorded yet"
        return
    fi
    
    local MSG="📊 *Today's Statistics*"$'\n\n'
    local TOTAL_TIME=0
    
    while IFS="|" read -r USER TIME; do
        local H=$((TIME/3600))
        local M=$(((TIME%3600)/60))
        
        MSG+="👤 *$USER* → ${H}h ${M}m"$'\n'
        TOTAL_TIME=$((TOTAL_TIME + TIME))
    done < <(jq -r 'to_entries | sort_by(-.value)[] | "\(.key)|\(.value)"' "$STATS")
    
    local TH=$((TOTAL_TIME/3600))
    local TM=$(((TOTAL_TIME%3600)/60))
    
    MSG+=$'\n'"⏱️ *Total Time:* ${TH}h ${TM}m"
    
    send_telegram "$MSG"
}

# COMMAND: TOP USER
cmd_top() {
    log "Executing: /top"
    
    local SOURCE="${1:-today}"
    local FILE="$STATS"
    local TITLE="Today's Top User"
    
    if [ "$SOURCE" = "month" ]; then
        FILE="$MONTHLY"
        TITLE="This Month's Top User"
    fi
    
    if [ ! -s "$FILE" ] || [ "$(cat "$FILE")" = "{}" ]; then
        send_telegram "🏆 No data available"
        return
    fi
    
    local TOP_USER=$(jq -r 'to_entries | sort_by(-.value)[] | .key' "$FILE" | head -1)
    local TOP_TIME=$(jq -r 'to_entries | sort_by(-.value)[] | .value' "$FILE" | head -1)
    
    local H=$((TOP_TIME/3600))
    local M=$(((TOP_TIME%3600)/60))
    
    local MSG="🏆 *$TITLE*"$'\n\n'
    MSG+="👤 *User:* $TOP_USER"$'\n'
    MSG+="⏱️ *Time:* ${H}h ${M}m"
    
    send_telegram "$MSG"
}

# COMMAND: ALL DEVICES
cmd_devices() {
    log "Executing: /devices"
    
    local MSG="📱 *All Configured Devices*"$'\n\n'
    local COUNT=0
    
    while IFS="|" read -r IP DEV_NAME USER; do
        [ -z "$IP" ] || [ "$IP" = "#" ] && continue
        
        local STATUS=$(tailscale status --json 2>/dev/null | jq -r ".Peer[] | select(.TailscaleIPs[0]==\"$IP\") | .Online" || echo "unknown")
        local EMOJI="🟢"
        [ "$STATUS" = "false" ] && EMOJI="🔴"
        
        MSG+="$EMOJI *$DEV_NAME*"$'\n'
        MSG+="   👤 $USER"$'\n\n'
        
        COUNT=$((COUNT + 1))
    done < "$CONFIG"
    
    MSG+="📊 *Total Devices:* $COUNT"
    
    send_telegram "$MSG"
}

# COMMAND: HELP
cmd_help() {
    log "Executing: /help"
    
    local MSG="📖 *Available Commands*"$'\n\n'
    MSG+="/status - Show server status"$'\n'
    MSG+="/online - List online devices"$'\n'
    MSG+="/offline - List offline devices"$'\n'
    MSG+="/devices - Show all devices"$'\n'
    MSG+="/stats - Show today's usage"$'\n'
    MSG+="/top - Show top user today"$'\n'
    MSG+="/top month - Show top user this month"$'\n'
    MSG+="/help - Show this message"$'\n\n'
    MSG+="💡 *Last Updated:* $(date '+%Y-%m-%d %H:%M')"
    
    send_telegram "$MSG"
}

# MAIN HANDLER
main() {
    local COMMAND="${1:-help}"
    local PARAM="${2:-}"
    
    log "Processing command: $COMMAND $PARAM"
    
    case "$COMMAND" in
        status) cmd_status ;;
        online) cmd_online ;;
        offline) cmd_offline ;;
        devices) cmd_devices ;;
        stats) cmd_stats ;;
        top) cmd_top "$PARAM" ;;
        help|--help|-h) cmd_help ;;
        *) cmd_help ;;
    esac
}

main "$@"
