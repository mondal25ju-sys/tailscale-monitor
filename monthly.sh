#!/bin/bash

# Tailscale Monitor - Monthly Usage Report
# Generates monthly statistics and archives data

set -euo pipefail

source ~/.tailscale-monitor.env

BASE="$HOME/tailscale-monitor/data"
LOGS="$HOME/tailscale-monitor/logs"
MONTHLY="$BASE/monthly.json"
MONTHLY_ARCHIVE="$BASE/monthly_archive.json"

mkdir -p "$BASE" "$LOGS"

LOG_FILE="$LOGS/monthly_$(date +%Y-%m).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_telegram() {
    local MSG="$1"
    
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d parse_mode="Markdown" \
        --data-urlencode text="$MSG" >/dev/null
    
    log "Message sent"
}

send_telegram_photo() {
    local PHOTO="$1"
    local CAPTION="$2"
    
    if [ ! -f "$PHOTO" ]; then
        log "WARNING: Photo not found"
        return 1
    fi
    
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendPhoto" \
        -F chat_id="$CHAT_ID" \
        -F photo=@"$PHOTO" \
        -F caption="$CAPTION" >/dev/null
    
    log "Photo sent"
}

DATE=$(date "+%B %Y")
YEAR_MONTH=$(date "+%Y-%m")

log "Starting monthly report for $DATE"

[ ! -f "$MONTHLY" ] && echo "{}" > "$MONTHLY"
[ ! -f "$MONTHLY_ARCHIVE" ] && echo "{}" > "$MONTHLY_ARCHIVE"

MSG="📊 *Monthly Usage Report*"$'\n'
MSG+="*Month:* $DATE"$'\n\n'

if [ ! -s "$MONTHLY" ] || [ "$(cat "$MONTHLY")" = "{}" ]; then
    MSG+="⏳ No usage recorded this month"
    log "No usage data"
else
    TOP_USER=""
    TOP_TIME=0
    TOTAL_TIME=0
    USER_COUNT=0
    
    log "Processing monthly data..."
    
    while IFS="|" read -r USER TIME; do
        
        H=$((TIME/3600))
        M=$(((TIME%3600)/60))
        
        MSG+="👤 *$USER* → ${H}h ${M}m"$'\n'
        TOTAL_TIME=$((TOTAL_TIME + TIME))
        USER_COUNT=$((USER_COUNT + 1))
        
        if [ "$TIME" -gt "$TOP_TIME" ]; then
            TOP_TIME=$TIME
            TOP_USER="$USER"
        fi
        
        log "User: $USER → ${H}h ${M}m"
        
    done < <(jq -r 'to_entries | sort_by(-.value)[] | "\(.key)|\(.value)"' "$MONTHLY")
    
    TH=$((TOTAL_TIME/3600))
    TM=$(((TOTAL_TIME%3600)/60))
    
    MSG+=$'\n'"📈 *Statistics:*"$'\n'
    MSG+="⏱️ *Total Time:* ${TH}h ${TM}m"$'\n'
    MSG+="👥 *Active Users:* $USER_COUNT"$'\n'
    
    if [ -n "$TOP_USER" ] && [ "$TOP_TIME" -gt 0 ]; then
        TH=$((TOP_TIME/3600))
        TM=$(((TOP_TIME%3600)/60))
        
        MSG+="🏆 *Top User:* $TOP_USER (${TH}h ${TM}m)"$'\n'
        log "Top user: $TOP_USER"
    fi
    
    log "Archiving monthly data..."
    MONTHLY_DATA=$(cat "$MONTHLY")
    MONTHLY_ARCHIVE_DATA=$(cat "$MONTHLY_ARCHIVE")
    
    MONTHLY_ARCHIVE_DATA=$(echo "$MONTHLY_ARCHIVE_DATA" | jq \
        --arg month "$YEAR_MONTH" \
        --argjson data "$MONTHLY_DATA" \
        '.[$month] = $data')
    
    echo "$MONTHLY_ARCHIVE_DATA" > "$MONTHLY_ARCHIVE"
    log "Archived: $YEAR_MONTH"
fi

log "Generating monthly graph..."
if [ -f "$HOME/tailscale-monitor/scripts/monthly_graph.py" ]; then
    python3 "$HOME/tailscale-monitor/scripts/monthly_graph.py" >> "$LOG_FILE" 2>&1 || log "ERROR: monthly_graph.py failed"
    GRAPH_FILE="$BASE/monthly.png"
fi

log "Sending Telegram report..."
send_telegram "$MSG"

if [ -f "$GRAPH_FILE" ]; then
    send_telegram_photo "$GRAPH_FILE" "Monthly Usage Chart - $DATE"
fi

log "Resetting monthly stats..."
echo "{}" > "$MONTHLY"

log "Monthly report completed"
