# tailscale-monitor
🌐 Tailscale Monitor - Complete Home Server Monitoring System
A comprehensive monitoring solution for Tailscale networks with real-time tracking, usage analytics, Telegram bot integration, and automated alerts.
✨ Features
📱 Real-time Device Tracking - Monitor which devices are connected/disconnected
📊 Usage Analytics - Track per-user online time and generate statistics
📈 Visual Charts - Weekly and monthly usage graphs
🤖 Telegram Bot - Interactive commands for instant status updates
🔔 Smart Alerts - Notifications for high usage, offline devices, and system issues
📧 Daily/Monthly Reports - Automated reports with graphs
📝 Complete Logging - Full audit trail for debugging
🔐 No Public IP Required - Works behind NAT/firewall
🏗️ System Architecture
```
┌─────────────────────────────────────────────┐
│     Tailscale Home Server (XXXXXXXXXX)       │
├─────────────────────────────────────────────┤
│                                             │
│  monitor.sh (Every 1 min)                  │
│  ├─ Tracks device connect/disconnect       │
│  ├─ Updates stats & timing data            │
│  └─ Sends instant Telegram alerts          │
│                                             │
│  bot_poller.sh (24/7 listening)            │
│  ├─ Receives /status, /online, etc.       │
│  ├─ Calls bot_commands.sh                  │
│  └─ Returns real-time info                 │
│                                             │
│  daily.sh (23:59 every day)                │
│  ├─ Generates daily report                 │
│  ├─ Creates weekly graph                   │
│  └─ Sends to Telegram                      │
│                                             │
│  monthly.sh (1st of month)                 │
│  ├─ Generates monthly report               │
│  ├─ Archives historical data               │
│  └─ Creates bar chart                      │
│                                             │
│  alerts.sh (On demand / scheduled)         │
│  ├─ Checks device offline duration         │
│  ├─ Monitors high usage                    │
│  ├─ Alerts on system resources             │
│  └─ Sends critical alerts                  │
│                                             │
└─────────────────────────────────────────────┘
         │
         │ Telegram API
         ▼
   ┌───────────────┐
   │ Telegram Bot  │
   │   Messages    │
   └───────────────┘
```
📁 Directory Structure
```
~/tailscale-monitor/
├── scripts/
│   ├── monitor.sh              # Main device tracking
│   ├── daily.sh                # Daily report generator
│   ├── monthly.sh              # Monthly report generator
│   ├── bot_commands.sh         # Telegram command handler
│   ├── bot_poller.sh           # Telegram bot listener
│   ├── alerts.sh               # Alert system
│   ├── graph.py                # Weekly chart generator
│   └── monthly_graph.py        # Monthly chart generator
│
├── data/
│   ├── state.json              # Current device state
│   ├── stats.json              # Today's usage statistics
│   ├── time.json               # Connection timing
│   ├── history.json            # Daily history (7 days)
│   ├── monthly.json            # Current month data
│   ├── monthly_archive.json    # Historical monthly data
│   ├── daily_report.json       # Daily reports archive
│   ├── weekly.png              # Weekly usage graph
│   └── monthly.png             # Monthly usage graph
│
├── logs/
│   ├── monitor.log             # Device tracking logs
│   ├── daily_*.log             # Daily report logs
│   ├── monthly_*.log           # Monthly report logs
│   ├── bot_commands_*.log      # Bot command logs
│   ├── bot_poller.log          # Bot listener logs
│   └── alerts_*.log            # Alert system logs
│
├── devices.conf                # Device configuration
└── README.md                   # This file
```
🚀 Quick Start
Prerequisites
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y jq curl python3-matplotlib

# macOS
brew install jq curl python3-matplotlib
```
Installation
Clone/Create Directory
```bash
mkdir -p ~/tailscale-monitor/{scripts,data,logs}
cd ~/tailscale-monitor
```
Copy Configuration Files
```bash
cp devices.conf.example devices.conf
# Edit with your device information
nano devices.conf
```
Set Up Environment
```bash
cat > ~/.tailscale-monitor.env << 'EOF'
BOT_TOKEN="your_telegram_bot_token"
CHAT_ID="your_telegram_chat_id"
EOF

chmod 600 ~/.tailscale-monitor.env
```
Copy All Scripts
```bash
cp scripts/* ~/tailscale-monitor/scripts/
chmod +x ~/tailscale-monitor/scripts/*.sh
chmod +x ~/tailscale-monitor/scripts/*.py
```
⚙️ Configuration
devices.conf Format
```
# IP | Device Name | User Name
XXX.XXX.XXX.XXX|oneplus-XXXX|XXXXXX Mobile
XXX.XXX.XXX.XXX|oneplus-XXXX|XXXXXX Laptop
XXX.XXX.XXX.XXX|HP-XXXX|XXXXXX Server
```
Get your device IPs:
```bash
tailscale status
```
Environment Variables (.tailscale-monitor.env)
```bash
# Get these from Telegram
BOT_TOKEN="your_bot_token_here"
CHAT_ID="your_chat_id_here"
```
Get Telegram Bot Token:
Message @BotFather on Telegram
Use `/newbot` command
Follow instructions
Copy the API token
Get Your Chat ID:
Message your bot
Send any command: `/start`
Visit: `https://api.telegram.org/botYOUR_BOT_TOKEN/getUpdates`
Find `chat.id` in JSON response
🔧 Setup Services
Option 1: Cron Jobs (Simple)
```bash
crontab -e
```
Add these lines:
```cron
# Monitor device connectivity (every minute)
* * * * * /bin/bash ~/tailscale-monitor/scripts/monitor.sh >> ~/tailscale-monitor/logs/monitor.log 2>&1

# Daily report (11:59 PM)
59 23 * * * /bin/bash ~/tailscale-monitor/scripts/daily.sh >> ~/tailscale-monitor/logs/daily.log 2>&1

# Monthly report (1st of month at 00:00)
0 0 1 * * /bin/bash ~/tailscale-monitor/scripts/monthly.sh >> ~/tailscale-monitor/logs/monthly.log 2>&1

# Run alerts (every 30 minutes)
*/30 * * * * /bin/bash ~/tailscale-monitor/scripts/alerts.sh all >> ~/tailscale-monitor/logs/alerts.log 2>&1
```
View cron logs:
```bash
grep CRON /var/log/syslog | tail -20
```
Option 2: Systemd Services (Recommended)
Bot Poller Service (Continuous)
```bash
sudo tee /etc/systemd/system/tailscale-bot-poller.service > /dev/null << 'EOF'
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
EOF

sudo systemctl daemon-reload
sudo systemctl enable tailscale-bot-poller
sudo systemctl start tailscale-bot-poller
sudo systemctl status tailscale-bot-poller
```
Monitor Timer (Every minute)
```bash
sudo tee /etc/systemd/system/tailscale-monitor.timer > /dev/null << 'EOF'
[Unit]
Description=Tailscale Monitor Timer
Requires=tailscale-monitor.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo tee /etc/systemd/system/tailscale-monitor.service > /dev/null << 'EOF'
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
EOF

sudo systemctl daemon-reload
sudo systemctl enable tailscale-monitor.timer
sudo systemctl start tailscale-monitor.timer
sudo systemctl status tailscale-monitor.timer
```
View systemd logs:
```bash
sudo journalctl -u tailscale-bot-poller -f
sudo journalctl -u tailscale-monitor.timer -f
```
📱 Telegram Bot Commands
Send these to your bot:
Command	Function
`/status`	Server status & online devices
`/online`	List all online devices
`/offline`	List all offline devices
`/devices`	Show all configured devices
`/stats`	Today's usage statistics
`/top`	Top user today
`/top month`	Top user this month
`/help`	Show all commands
📊 Data Files
stats.json (Daily)
```json
{
  "XXXXX Mobile": 3600,
  "XXXX Laptop": 7200,
  "Home Server": 86400
}
```
monthly.json (Monthly)
```json
{
  "XXXXXX Mobile": 1080000,
  "XXXXX Laptop": 2160000
}
```
history.json (7-day history)
```json
{
  "2026-05-25": {
    "XXXXXXX Mobile": 3600,
    "XXXXXXXX Laptop": 7200
  },
  "2026-05-26": {
    "XXXXXX Mobile": 5400
  }
}
```
🔔 Alert Configuration
Alerts are triggered for:
High Usage (>18 hours/day)
Device Offline (>24 hours)
All Devices Offline (Critical)
System Resources (CPU >80%, Disk >85%, Memory >80%)
Manually trigger:
```bash
bash ~/tailscale-monitor/scripts/alerts.sh all       # All checks
bash ~/tailscale-monitor/scripts/alerts.sh resources # System only
bash ~/tailscale-monitor/scripts/alerts.sh devices   # Device checks
bash ~/tailscale-monitor/scripts/alerts.sh usage     # Usage checks
```
📊 Generate Graphs
```bash
# Weekly graph
python3 ~/tailscale-monitor/scripts/graph.py

# Monthly graph
python3 ~/tailscale-monitor/scripts/monthly_graph.py
```
Graphs saved to: `~/tailscale-monitor/data/weekly.png` and `monthly.png`
🐛 Troubleshooting
Bot not responding?
```bash
# Check if poller is running
systemctl status tailscale-bot-poller

# View recent logs
sudo journalctl -u tailscale-bot-poller -n 50

# Test manually
bash ~/tailscale-monitor/scripts/bot_poller.sh
```
No data in reports?
```bash
# Check if monitor.sh is running
ps aux | grep monitor.sh

# View monitor logs
tail -50 ~/tailscale-monitor/logs/monitor.log

# Check data files
jq . ~/tailscale-monitor/data/stats.json
```
Telegram errors?
```bash
# Verify bot token
curl https://api.telegram.org/bot$BOT_TOKEN/getMe

# Verify chat ID
curl "https://api.telegram.org/bot$BOT_TOKEN/getUpdates" | jq '.result[0].message.chat.id'

# Test sending message
curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
  -d chat_id="$CHAT_ID" \
  -d text="Test message"
```
Check all logs
```bash
# Real-time bot logs
sudo journalctl -u tailscale-bot-poller -f

# Monitor logs
tail -f ~/tailscale-monitor/logs/monitor.log

# All recent logs
ls -lhtr ~/tailscale-monitor/logs/ | tail -10
```
📈 Monitoring
Check service status:
```bash
# Systemd services
systemctl status tailscale-bot-poller
systemctl list-timers --all | grep tailscale

# Cron jobs
crontab -l
```
View logs:
```bash
# Last 100 lines
tail -100 ~/tailscale-monitor/logs/bot_poller.log

# Follow in real-time
tail -f ~/tailscale-monitor/logs/monitor.log

# Search for errors
grep ERROR ~/tailscale-monitor/logs/*.log
```
🔐 Security Notes
✅ Store `~/.tailscale-monitor.env` securely (chmod 600)
✅ Telegram bot tokens are sensitive - don't share them
✅ Chat IDs are personal - keep private
✅ All logs contain timestamps but no sensitive data
✅ Scripts run with user permissions (no sudo needed for monitoring)
📝 Maintenance
Daily
✅ Reports generated at 11:59 PM
✅ Device tracking runs every minute
✅ Bot responds to commands 24/7
Weekly
✅ Graph updates daily with 7-day history
Monthly
✅ Report and data archiving on 1st
✅ Historical data persists indefinitely
Cleanup
```bash
# Archive old logs (keep last 30 days)
find ~/tailscale-monitor/logs -name "*.log" -mtime +30 -delete

# Clear very old data (keep last 90 days)
find ~/tailscale-monitor/data -name "history_*.json" -mtime +90 -delete
```
🤝 Support & Contributions
For issues or improvements:
Check troubleshooting section
Review logs for errors
Verify configuration
Test commands manually
📄 License
MIT License - Feel free to modify and distribute
🙏 Credits
Built for home server monitoring with Tailscale and Telegram integration.
---
Last Updated: 2026-05-31
Version: 1.0.0
Status: ✅ Production Ready
