#!/bin/bash

# Tailscale Monitor - Telegram Bot Poller
# Continuously listens for Telegram messages and routes commands

set -euo pipefail

source ~/.tailscale-monitor.env

BASE="$HOME/tailscale-monitor"
SCRIPTS="$BASE/scripts"
LOGS="$BASE/logs"

mkdir -p "$LOGS"

LOG_FILE="$LOGS/bot_poller.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🤖 Telegram Bot Poller Started"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    log "ERROR: BOT_TOKEN or CHAT_ID not configured"
    exit 1
fi

if [ ! -f "$SCRIPTS/bot_commands.sh" ]; then
    log "ERROR: bot_commands.sh not found"
    exit 1
fi

send_telegram() {
    local MSG="$1"
    
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d parse_mode="Markdown" \
        --data-urlencode text="$MSG" >/dev/null
}

OFFSET=0
ERROR_COUNT=0
MAX_ERRORS=10

log "Starting polling loop with 30-second timeout..."

while true; do
    
    RESPONSE=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$OFFSET&timeout=30&allowed_updates=message" 2>/dev/null || echo '{"ok":false}')
    
    if ! echo "$RESPONSE" | jq . >/dev/null 2>&1; then
        ERROR_COUNT=$((ERROR_COUNT + 1))
        log "ERROR: Invalid JSON response (error count: $ERROR_COUNT)"
        
        if [ $ERROR_COUNT -ge $MAX_ERRORS ]; then
            log "ERROR: Too many errors, restarting"
            sleep 10
            ERROR_COUNT=0
        fi
        sleep 5
        continue
    fi
    
    ERROR_COUNT=0
    
    while IFS= read -r update; do
        
        if [ -z "$update" ]; then
            continue
        fi
        
        UPDATE_ID=$(echo "$update" | jq -r '.update_id')
        MESSAGE_TEXT=$(echo "$update" | jq -r '.message.text // empty')
        FROM_NAME=$(echo "$update" | jq -r '.message.from.first_name // "User"')
        
        if [ -z "$MESSAGE_TEXT" ]; then
            OFFSET=$((UPDATE_ID + 1))
            continue
        fi
        
        if [[ ! "$MESSAGE_TEXT" =~ ^/ ]]; then
            OFFSET=$((UPDATE_ID + 1))
            continue
        fi
        
        COMMAND=$(echo "$MESSAGE_TEXT" | awk '{print $1}' | sed 's/^//' | tr '[:upper:]' '[:lower:]')
        COMMAND="${COMMAND#/}"
        PARAMS=$(echo "$MESSAGE_TEXT" | awk '{$1=""; print $0}' | xargs)
        
        log "📨 Received: /$COMMAND from $FROM_NAME"
        
        if bash "$SCRIPTS/bot_commands.sh" "$COMMAND" "$PARAMS" 2>>"$LOG_FILE"; then
            log "✅ Command executed: /$COMMAND"
        else
            log "❌ Error executing: /$COMMAND"
            send_telegram "❌ Error executing command: /$COMMAND"
        fi
        
        OFFSET=$((UPDATE_ID + 1))
        
    done < <(echo "$RESPONSE" | jq -c '.result[]? | select(.message.text | startswith("/"))')
    
done

log "🤖 Telegram Bot Poller Stopped"
