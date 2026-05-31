# 🚀 Tailscale Monitor - Complete Setup Guide

A detailed step-by-step installation and configuration guide.

## 📋 Pre-requisites

- Ubuntu/Debian Linux or macOS
- Tailscale installed and configured
- Docker (optional, for containerized setup)
- Python 3.6+
- Telegram account and bot

## 🔧 Step 1: Install Dependencies

### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install -y \
  jq \
  curl \
  python3 \
  python3-pip \
  git

# Install Python dependencies
pip3 install matplotlib numpy
```

### macOS

```bash
brew install jq curl python3 git
pip3 install matplotlib numpy
```

### Verify Installation

```bash
jq --version
curl --version
python3 --version
tailscale status
```

## 🔐 Step 2: Create Telegram Bot

### Create Bot via BotFather

1. Open Telegram and search for **@BotFather**
2. Send `/newbot`
3. Choose a name: `Home Server Status`
4. Choose username: `home_server_bot` (must be unique)
5. BotFather gives you a **TOKEN**: `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`
6. Save this token securely

### Get Your Chat ID

1. Message your newly created bot
2. Send `/start`
3. In browser, visit:
   ```
   https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
   ```
4. Look for `"chat"` → `"id"` (example: `1377556793`)
5. Save this ID

### Set Bot Commands (Optional)

```bash
# In Telegram with BotFather
/setcommands

# Add these commands:
status - Show server status
online - List online devices
offline - List offline devices
devices - Show all devices
stats - Today statistics
top - Top user today
help - Show help
```

## 📁 Step 3: Create Directory Structure

```bash
# Create base directory
mkdir -p ~/tailscale-monitor/{scripts,data,logs}

# Set permissions
chmod 755 ~/tailscale-monitor
chmod 755 ~/tailscale-monitor/{scripts,data,logs}

# Verify
ls -la ~/tailscale-monitor/
```

## 🔑 Step 4: Configure Environment

```bash
# Create environment file
cat > ~/.tailscale-monitor.env << 'EOF'
BOT_TOKEN="your_telegram_bot_token_here"
CHAT_ID="your_telegram_chat_id_here"
EOF

# Secure the file
chmod 600 ~/.tailscale-monitor.env

# Verify
cat ~/.tailscale-monitor.env
```

## 📱 Step 5: Create Device Configuration

Get your device IPs:
```bash
tailscale status
```

Create configuration file:
```bash
cat > ~/tailscale-monitor/devices.conf << 'EOF'
# IP | Device Name | User Name
100.96.203.37|oneplus-iv2201|Prasanna Mobile
100.95.42.111|myhome-nuc7pjyhn|Home Server
100.70.89.70|thunderbolt|Prasana Laptop
100.88.242.128|oppo-cph2625|Samapti Mobile
100.125.68.108|oppo-a3-pro-5g|Mama Mobile
100.97.149.22|poco-m6-5g|Prasanna Poco
EOF
```

## 📝 Step 6: Copy All Scripts

### Option A: Manual Copy

Create each script file with provided content:

```bash
# 1. Copy monitor.sh
nano ~/tailscale-monitor/scripts/monitor.sh
# [paste content]

# 2. Copy daily.sh
nano ~/tailscale-monitor/scripts/daily.sh
# [paste content]

# 3. Copy monthly.sh
nano ~/tailscale-monitor/scripts/monthly.sh
# [paste content]

# 4. Copy bot_commands.sh
nano ~/tailscale-monitor/scripts/bot_commands.sh
# [paste content]

# 5. Copy bot_poller.sh
nano ~/tailscale-monitor/scripts/bot_poller.sh
# [paste content]

# 6. Copy alerts.sh
nano ~/tailscale-monitor/scripts/alerts.sh
# [paste content]

# 7. Copy graph.py
nano ~/tailscale-monitor/scripts/graph.py
# [paste content]

# 8. Copy monthly_graph.py
nano ~/tailscale-monitor/scripts/monthly_graph.py
# [paste content]
```

### Option B: Automated Copy (if from Git/Source)

```bash
cd ~/tailscale-monitor
git clone <repo-url> .
```

### Make Executable

```bash
chmod +x ~/tailscale-monitor/scripts/*.sh
chmod +x ~/tailscale-monitor/scripts/*.py
```

## ✅ Step 7: Test Each Component

### Test 1: Monitor Script

```bash
bash ~/tailscale-monitor/scripts/monitor.sh
```

Expected: Check logs for device status
```bash
tail ~/tailscale-monitor/logs/monitor.log
```

### Test 2: Bot Commands

```bash
bash ~/tailscale-monitor/scripts/bot_commands.sh status
bash ~/tailscale-monitor/scripts/bot_commands.sh online
bash ~/tailscale-monitor/scripts/bot_commands.sh help
```

You should receive Telegram messages!

### Test 3: Bot Poller

```bash
# Start in background
bash ~/tailscale-monitor/scripts/bot_poller.sh &

# Get the PID
BOT_PID=$!

# Send test command in Telegram: /status
sleep 5

# Stop
kill $BOT_PID
```

### Test 4: Graphs

```bash
python3 ~/tailscale-monitor/scripts/graph.py
python3 ~/tailscale-monitor/scripts/monthly_graph.py

# Check output
ls -lh ~/tailscale-monitor/data/*.png
```

### Test 5: Alerts

```bash
bash ~/tailscale-monitor/scripts/alerts.sh resources
bash ~/tailscale-monitor/scripts/alerts.sh all
```

## ⏰ Step 8: Schedule Services

### Option A: Cron (Simple)

```bash
crontab -e
```

Add:
```cron
# Device monitoring (every minute)
* * * * * /bin/bash ~/tailscale-monitor/scripts/monitor.sh >> ~/tailscale-monitor/logs/monitor.log 2>&1

# Daily report (11:59 PM)
59 23 * * * /bin/bash ~/tailscale-monitor/scripts/daily.sh >> ~/tailscale-monitor/logs/daily.log 2>&1

# Monthly report (1st of month)
0 0 1 * * /bin/bash ~/tailscale-monitor/scripts/monthly.sh >> ~/tailscale-monitor/logs/monthly.log 2>&1

# Alerts (every 30 minutes)
*/30 * * * * /bin/bash ~/tailscale-monitor/scripts/alerts.sh all >> ~/tailscale-monitor/logs/alerts.log 2>&1
```

Verify:
```bash
crontab -l
```

### Option B: Systemd (Recommended)

#### Setup Bot Poller

```bash
# Create service file
sudo tee /etc/systemd/system/tailscale-bot-poller.service > /dev/null << 'SYSTEMD'
[Unit]
Description=Tailscale Telegram Bot Poller
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=myhome
WorkingDirectory=/home/myhome/tailscale-monitor
ExecStart=/bin/bash /home/myhome/tailscale-monitor/scripts/bot_poller.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SYSTEMD

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable tailscale-bot-poller
sudo systemctl start tailscale-bot-poller

# Verify
sudo systemctl status tailscale-bot-poller
```

#### Setup Monitor Timer

```bash
# Create timer
sudo tee /etc/systemd/system/tailscale-monitor.timer > /dev/null << 'TIMER'
[Unit]
Description=Tailscale Monitor Timer
Requires=tailscale-monitor.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Persistent=true

[Install]
WantedBy=timers.target
TIMER

# Create service
sudo tee /etc/systemd/system/tailscale-monitor.service > /dev/null << 'SERVICE'
[Unit]
Description=Tailscale Device Monitor
After=network-online.target

[Service]
Type=oneshot
User=myhome
ExecStart=/bin/bash /home/myhome/tailscale-monitor/scripts/monitor.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable tailscale-monitor.timer
sudo systemctl start tailscale-monitor.timer

# Verify
sudo systemctl list-timers --all | grep tailscale
```

## 🔍 Step 9: Verify Installation

### Check All Services

```bash
# Systemd services
systemctl status tailscale-bot-poller
systemctl list-timers --all | grep tailscale

# Cron jobs
crontab -l

# Processes
ps aux | grep tailscale-monitor
```

### Check Logs

```bash
# Monitor logs
tail -20 ~/tailscale-monitor/logs/monitor.log

# Bot logs
sudo journalctl -u tailscale-bot-poller -n 20

# All logs
ls -lh ~/tailscale-monitor/logs/
```

### Send Test Messages

In Telegram:
```
/help
/status
/online
/stats
```

All should respond within 5 seconds.

## 📊 Step 10: Monitor Dashboard

### View Real-time Logs

```bash
# Bot poller (live)
sudo journalctl -u tailscale-bot-poller -f

# Monitor (live)
tail -f ~/tailscale-monitor/logs/monitor.log

# Alerts
tail -f ~/tailscale-monitor/logs/alerts_*.log
```

### Check Data Files

```bash
# Current status
jq . ~/tailscale-monitor/data/state.json

# Today's stats
jq . ~/tailscale-monitor/data/stats.json

# This month
jq . ~/tailscale-monitor/data/monthly.json

# 7-day history
jq . ~/tailscale-monitor/data/history.json
```

## 🚨 Troubleshooting

### Bot not responding?

```bash
# 1. Check if service is running
systemctl status tailscale-bot-poller

# 2. Restart service
sudo systemctl restart tailscale-bot-poller

# 3. Check recent logs
sudo journalctl -u tailscale-bot-poller -n 50

# 4. Verify bot token
curl https://api.telegram.org/botYOUR_TOKEN/getMe
```

### No device data?

```bash
# 1. Check monitor is running
ps aux | grep monitor.sh

# 2. Run manually
bash ~/tailscale-monitor/scripts/monitor.sh

# 3. Check data files
ls -lh ~/tailscale-monitor/data/

# 4. Verify devices.conf
cat ~/tailscale-monitor/devices.conf

# 5. Check tailscale
tailscale status
```

### Cron jobs not running?

```bash
# Check crontab
crontab -l

# Check cron logs
grep CRON /var/log/syslog | tail -20

# Run job manually
/bin/bash ~/tailscale-monitor/scripts/monitor.sh

# Check for errors
bash -x ~/tailscale-monitor/scripts/monitor.sh 2>&1
```

### Python graph errors?

```bash
# Test graph script
python3 ~/tailscale-monitor/scripts/graph.py

# Check dependencies
pip3 list | grep matplotlib

# Install if missing
pip3 install matplotlib numpy

# Verify data exists
jq . ~/tailscale-monitor/data/history.json
```

## 🎉 Success Indicators

You'll know it's working when:

✅ Bot responds to `/status` within 5 seconds
✅ Monitor logs show device updates every minute
✅ Daily report arrives at 11:59 PM
✅ Graphs are generated and included in reports
✅ Alerts sent for high usage or offline devices
✅ `/online` shows connected devices
✅ `/stats` shows usage data
✅ No error messages in logs

## 📚 Next Steps

1. **Customize Alerts** - Edit thresholds in alerts.sh
2. **Add More Devices** - Update devices.conf
3. **Review Reports** - Check Telegram daily
4. **Monitor Graphs** - Weekly usage trends
5. **Archive Data** - Setup cleanup jobs

## 📞 Support

For issues:
1. Check logs: `~/tailscale-monitor/logs/`
2. Run tests manually
3. Verify configuration
4. Review README.md
5. Check Telegram bot token and chat ID

---

**Setup Time:** ~30 minutes
**Maintenance:** Minimal (automated)
**Status:** Ready to deploy 🚀