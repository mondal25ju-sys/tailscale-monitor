#!/bin/bash

# Tailscale Monitor - Daily Usage Report
# Generates daily statistics and sends Telegram notifications

set -euo pipefail

source ~/.tailscale-monitor.env

BASE="$HOME/tailscale-monitor/data"
CONFIG="$HOME/tailscale-monitor/devices.conf"
LOGS="$HOME/tailscale-monitor/logs"

STATS="$BASE/stats.json"
TIME_FILE="$BASE/time.json"
HISTORY="$BASE/history.json"
MONTHLY="$BASE/monthly.json"
DAILY_REPORT="$BASE/daily_report.json"

mkdir -p "$BASE" "$LOGS"

LOG_FILE="$LOGS/daily_$(date +%Y-%m-%d).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_device_info() {
    local IP="$1"
    local LINE=$(grep "^$IP|" "$CONFIG" 2>/dev/null || echo "")
    
    if [ -n "$LINE" ]; then
        echo "$LINE" | cut -d'|' -f3 | xargs
    else
        echo "Unknown User"
    fi
}

send_telegram() {
    local MSG="$1"
    
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d parse_mode="Markdown" \
        --data-urlencode text="$MSG" >/dev/null
    
    log "Telegram message sent"
}

send_telegram_photo() {
    local PHOTO="$1"
    
    if [ ! -f "$PHOTO" ]; then
        log "WARNING: Photo not found: $PHOTO"
        return 1
    fi
    
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendPhoto" \
        -F chat_id="$CHAT_ID" \
        -F photo=@"$PHOTO" >/dev/null
    
    log "Telegram photo sent"
}

DATE=$(date "+%Y-%m-%d")
NOW_TS=$(date +%s)

log "Starting daily report for $DATE"

[ ! -f "$HISTORY" ] && echo "{}" > "$HISTORY"
[ ! -f "$MONTHLY" ] && echo "{}" > "$MONTHLY"
[ ! -f "$STATS" ] && echo "{}" > "$STATS"
[ ! -f "$DAILY_REPORT" ] && echo "{}" > "$DAILY_REPORT"
[ ! -f "$TIME_FILE" ] && echo "{}" > "$TIME_FILE"

MSG="📅 *Daily Usage Report*"$'\n'
MSG+="*Date:* $DATE"$'\n\n'

COMBINED=$(cat "$STATS")

COMBINED_LENGTH=$(echo "$COMBINED" | jq 'length')

if [ "$COMBINED_LENGTH" -eq 0 ]; then
    MSG+="⏳ No usage recorded today"
    log "No usage data"
else
    TMP_HISTORY=$(cat "$HISTORY")
    TMP_MONTHLY=$(cat "$MONTHLY")
    TMP_REPORT=$(cat "$DAILY_REPORT")
    
    TOP_USER=""
    TOP_TIME=0
    TOTAL_TIME=0
    
    while IFS="|" read -r USER TIME; do
        
        H=$((TIME/3600))
        M=$(((TIME%3600)/60))
        
        MSG+="👤 *$USER* → ${H}h ${M}m"$'\n'
        TOTAL_TIME=$((TOTAL_TIME + TIME))
        
        TMP_HISTORY=$(echo "$TMP_HISTORY" | jq \
            --arg date "$DATE" \
            --arg user "$USER" \
            --argjson time "$TIME" \
            '.[$date][$user] = $time')
        
        TMP_MONTHLY=$(echo "$TMP_MONTHLY" | jq \
            --arg user "$USER" \
            --argjson time "$TIME" \
            '.[$user] = ((.[$user] // 0) + $time)')
        
        TMP_REPORT=$(echo "$TMP_REPORT" | jq \
            --arg date "$DATE" \
            --arg user "$USER" \
            --argjson time "$TIME" \
            '.[$date][$user] = $time')
        
        if [ "$TIME" -gt "$TOP_TIME" ]; then
            TOP_TIME=$TIME
            TOP_USER="$USER"
        fi
        
        log "User: $USER → ${H}h ${M}m"
        
    done < <(echo "$COMBINED" | jq -r 'to_entries | sort_by(-.value)[] | "\(.key)|\(.value)"')
    
    TH=$((TOTAL_TIME/3600))
    TM=$(((TOTAL_TIME%3600)/60))
    
    MSG+=$'\n'"📊 *Total Time:* ${TH}h ${TM}m"$'\n'
    
    if [ -n "$TOP_USER" ] && [ "$TOP_TIME" -gt 0 ]; then
        TH=$((TOP_TIME/3600))
        TM=$(((TOP_TIME%3600)/60))
        
        MSG+="🏆 *Top User:* $TOP_USER (${TH}h ${TM}m)"$'\n'
        log "Top user: $TOP_USER"
    fi
    
    echo "$TMP_HISTORY" > "$HISTORY"
    echo "$TMP_MONTHLY" > "$MONTHLY"
    echo "$TMP_REPORT" > "$DAILY_REPORT"
    
    log "Daily data updated"
fi

DEVICE_COUNT=$(tailscale status --json 2>/dev/null | jq '.Peer | length' || echo "0")
MSG+=$'\n'"📱 *Devices:* $DEVICE_COUNT"

log "Generating graph..."
if [ -f "$HOME/tailscale-monitor/scripts/graph.py" ]; then
    python3 "$HOME/tailscale-monitor/scripts/graph.py" >> "$LOG_FILE" 2>&1 || log "ERROR: graph.py failed"
    GRAPH_FILE="$BASE/weekly.png"
fi

log "Sending Telegram report..."
send_telegram "$MSG"

if [ -f "$GRAPH_FILE" ]; then
    send_telegram_photo "$GRAPH_FILE"
fi

log "Resetting daily stats..."
echo "{}" > "$STATS"

log "Daily report completed"
