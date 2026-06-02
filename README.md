# 🌐 Tailscale Monitor - Complete Home Server Monitoring System

A comprehensive, open-source monitoring solution for Tailscale networks with real-time device tracking, usage analytics, Telegram bot integration, and automated alerts.

## ✨ Key Features

- 📱 **Real-time Device Tracking** - Monitor device connection/disconnection events instantly
- 📊 **Usage Analytics** - Track per-user online time with detailed statistics
- 📈 **Visual Charts** - Automated weekly and monthly usage graphs
- 🤖 **Telegram Bot** - Interactive 24/7 command interface for instant status updates
- 🔔 **Smart Alerts** - Customizable Telegram notifications for high usage, offline devices, and system issues
- 📧 **Daily/Monthly Reports** - Automated reports with visualizations sent via Telegram
- 📝 **Comprehensive Logging** - Full audit trail for debugging and monitoring
- 🔐 **Privacy-First** - No public IP required, works behind NAT/firewall, local-only file storage
- 🎯 **Fully Customizable** - Adjust alert thresholds, add custom alerts, extend functionality

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────┐
│         Home Server (Your Device)               │
├─────────────────────────────────────────────────┤
│                                                 │
│ ⏰ monitor.sh (Every 1 minute)                 │
│ └─ Tracks device connect/disconnect            │
│ └─ Updates stats and timing data                │
│ └─ Sends instant Telegram alerts                │
│                                                 │
│ 🤖 bot_poller.sh (24/7 Continuous)             │
│ └─ Listens for Telegram commands               │
│ └─ Executes bot_commands.sh                    │
│ └─ Returns real-time device information         │
│                                                 │
│ 📊 daily.sh (23:59 Every Day)                  │
│ └─ Generates daily usage report                │
│ └─ Creates weekly graph (7 days)                │
│ └─ Sends via Telegram                          │
│                                                 │
│ 📈 monthly.sh (1st of Month)                   │
│ └─ Generates monthly report                    │
│ └─ Archives historical data                    │
│ └─ Creates bar chart                           │
│                                                 │
│ 🔔 alerts_advanced.sh (Scheduled)              │
│ └─ Monitors high usage                         │
│ └─ Checks offline devices                      │
│ └─ Alerts on system resources (CPU/Memory/Disk)│
│                                                 │
│ 📊 graph.py & monthly_graph.py                 │
│ └─ Generates visualization charts               │
│                                                 │
└─────────────────────────────────────────────────┘
         │
         │ Telegram API
         ▼
   ┌──────────────────┐
   │   Telegram Bot   │
   │   24/7 Active    │
   └──────────────────┘
```

## 📁 Directory Structure

```
tailscale-monitor/
├── scripts/
│   ├── monitor.sh              # Device tracking (1 min interval)
│   ├── daily.sh                # Daily report generator
│   ├── monthly.sh              # Monthly report generator
│   ├── bot_commands.sh         # Telegram command handler
│   ├── bot_poller.sh           # Telegram bot listener (24/7)
│   ├── alerts_advanced.sh      # Alert system with 12+ types
│   ├── graph.py                # Weekly chart generator
│   └── monthly_graph.py        # Monthly chart generator
│
├── data/
│   ├── state.json              # Current device state
│   ├── stats.json              # Today's usage statistics
│   ├── time.json               # Connection timing
│   ├── history.json            # 7-day history
│   ├── monthly.json            # Current month data
│   ├── monthly_archive.json    # Historical monthly data
│   ├── alerts_state.json       # Alert cooldown tracking
│   ├── weekly.png              # Weekly usage graph
│   └── monthly.png             # Monthly usage graph
│
├── logs/
│   ├── monitor.log             # Device tracking logs
│   ├── daily_*.log             # Daily report logs
│   ├── monthly_*.log           # Monthly report logs
│   ├── bot_commands_*.log      # Bot command logs
│   ├── bot_poller.log          # Bot listener logs
│   ├── alerts_*.log            # Alert system logs
│   └── graph.log               # Graph generation logs
│
├── devices.conf                # Device configuration
├── config_example.env          # Configuration template
├── devices.conf.example        # Device config template
├── .gitignore                  # Git ignore rules
├── README.md                   # This file
└── SETUP_GUIDE.md             # Step-by-step setup
```

## 🚀 Quick Start (5 Minutes)

### 1. Prerequisites

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y jq curl python3 python3-pip
pip3 install matplotlib numpy

# macOS
brew install jq curl python3
pip3 install matplotlib numpy
```

### 2. Clone Repository

```bash
git clone https://github.com/yourusername/tailscale-monitor.git
cd tailscale-monitor
```

### 3. Setup Configuration

```bash
# Create environment file
cp config_example.env ~/.tailscale-monitor.env
nano ~/.tailscale-monitor.env
chmod 600 ~/.tailscale-monitor.env
```

### 4. Configure Devices

```bash
# Get your device IPs
tailscale status

# Copy and edit device configuration
cp devices.conf.example devices.conf
nano devices.conf
```

### 5. Make Scripts Executable

```bash
chmod +x scripts/*.sh
chmod +x scripts/*.py
```

### 6. Test Bot

```bash
bash scripts/bot_poller.sh &
sleep 2
# Send /help in Telegram
kill %1
```

### 7. Setup Services

**Option A: Systemd (Recommended)**
```bash
sudo systemctl start tailscale-bot-poller
sudo systemctl enable tailscale-bot-poller
```

**Option B: Cron**
```bash
crontab -e
# Add scheduling (see SETUP_GUIDE.md)
```

## 📱 Telegram Bot Commands

| Command | Function |
|---------|----------|
| `/status` | Server status & online device count |
| `/online` | List all currently online devices |
| `/offline` | List all currently offline devices |
| `/devices` | Show all configured devices |
| `/stats` | Today's usage statistics |
| `/top` | Top user today |
| `/top month` | Top user this month |
| `/help` | Show all commands |

## 🔔 12+ Alert Types

✅ Device connected
❌ Device disconnected
⏱️ Long active session (>12 hours)
⚠️ High daily usage (>18 hours)
🚨 Critical usage (>22 hours)
🚨 Device offline too long (>72 hours)
🚨 All devices offline
🔴 High CPU usage (>80%)
🟡 High memory usage (>80%)
💾 Low disk space (>85%)
🚨 Tailscale server unreachable
📊 Daily summary report

## ⚙️ Configuration

### ~/.tailscale-monitor.env

```bash
BOT_TOKEN="your_bot_token_here"
CHAT_ID="your_chat_id_here"
```

### devices.conf

```
# Format: IP | Device Name | User/Owner Name
100.64.1.1|laptop|John Doe
100.64.1.2|phone|Jane Smith
100.64.1.3|tablet|Family Device
```

### Alert Thresholds (in alerts_advanced.sh)

```bash
HIGH_USAGE_HOURS=18              # Warning threshold
CRITICAL_USAGE_HOURS=22          # Critical threshold
CPU_THRESHOLD=80                 # CPU %
MEMORY_THRESHOLD=80              # Memory %
DISK_THRESHOLD=85                # Disk %
```

## 📊 Data Files

### stats.json (Today's Usage)
```json
{
  "User Name": 3600,
  "Another User": 7200
}
```
Values are in seconds.

### monthly.json (Current Month)
```json
{
  "User Name": 1080000,
  "Another User": 2160000
}
```

### history.json (7-Day History)
```json
{
  "2024-01-15": {
    "User Name": 3600,
    "Another User": 7200
  }
}
```

## 🧪 Testing

```bash
# Test monitor script
bash scripts/monitor.sh

# Test bot commands
bash scripts/bot_commands.sh status
bash scripts/bot_commands.sh help

# Test alerts
bash scripts/alerts_advanced.sh all

# Test graphs
python3 scripts/graph.py
python3 scripts/monthly_graph.py

# View logs
tail -50 logs/*.log
```

## 📚 Documentation

- **README.md** - Overview and features (this file)
- **SETUP_GUIDE.md** - Complete step-by-step installation guide
- **config_example.env** - Configuration template
- **devices.conf.example** - Device configuration example

## 🐛 Troubleshooting

### Bot not responding?

```bash
sudo systemctl status tailscale-bot-poller
sudo journalctl -u tailscale-bot-poller -f
sudo systemctl restart tailscale-bot-poller
```

### No device data?

```bash
ps aux | grep monitor.sh
bash scripts/monitor.sh
jq . data/stats.json
```

### Graph errors?

```bash
python3 scripts/graph.py
pip3 list | grep matplotlib
pip3 install --upgrade matplotlib numpy
```

## 🔐 Security Notes

✅ Store `~/.tailscale-monitor.env` securely (chmod 600)
✅ Telegram bot tokens are sensitive - don't share them
✅ All identifiable data redacted in this repository
✅ No sensitive data logged or stored
✅ Scripts run with user permissions (no sudo needed)
✅ Works behind NAT/firewall (no public IP needed)

## 📈 Monitoring

Check service status:
```bash
systemctl status tailscale-bot-poller
sudo systemctl list-timers --all | grep tailscale
crontab -l
tail -f logs/*.log
```

## 📝 Maintenance

### Daily
- ✅ Reports generated at 11:59 PM
- ✅ Device tracking runs every minute
- ✅ Bot responds to commands 24/7

### Weekly
- ✅ Graph updates with 7-day history

### Monthly
- ✅ Report and data archiving on 1st
- ✅ Historical data preserved indefinitely

### Cleanup (Optional)
```bash
find logs -name "*.log" -mtime +30 -delete
find data -name "*.json" -mtime +90 -delete
```

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test thoroughly
4. Submit a pull request

## 📄 License

MIT License - Feel free to use, modify, and distribute

## 🙏 Credits

Built for home server monitoring with Tailscale and Telegram integration.

---

**Version:** 1.0.0
**Last Updated:** 2024-06-02
**Status:** ✅ Production Ready
**Support:** See SETUP_GUIDE.md for detailed help

🚀 **Ready to monitor your Tailscale network!**
