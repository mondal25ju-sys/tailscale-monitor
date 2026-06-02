#!/usr/bin/env python3

"""
Tailscale Monitor - Weekly Graph Generator
Generates usage charts from historical data
"""

import json
import sys
from datetime import datetime, timedelta
from pathlib import Path

try:
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    from matplotlib.ticker import MaxNLocator, FixedLocator
    import numpy as np
except ImportError:
    print("ERROR: matplotlib not installed. Run: pip3 install matplotlib numpy")
    sys.exit(1)

BASE_DIR = Path.home() / "tailscale-monitor" / "data"
HISTORY_FILE = BASE_DIR / "history.json"
OUTPUT_FILE = BASE_DIR / "weekly.png"
LOG_FILE = Path.home() / "tailscale-monitor" / "logs" / "graph.log"

def log(msg):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {msg}")
    try:
        Path(LOG_FILE).parent.mkdir(parents=True, exist_ok=True)
        with open(LOG_FILE, 'a') as f:
            f.write(f"[{timestamp}] {msg}\n")
    except:
        pass

def load_history():
    if not HISTORY_FILE.exists():
        log("WARNING: history.json not found")
        return {}
    
    try:
        with open(HISTORY_FILE, 'r') as f:
            return json.load(f)
    except:
        log("ERROR: Failed to load history.json")
        return {}

def prepare_data():
    history = load_history()
    
    if not history:
        return [], {}
    
    dates = []
    data = {}
    
    for i in range(6, -1, -1):
        date = (datetime.now() - timedelta(days=i)).strftime("%Y-%m-%d")
        dates.append(date)
        
        if date in history:
            for user, seconds in history[date].items():
                if user not in data:
                    data[user] = []
                data[user].append(seconds / 3600)
    
    for user in data:
        while len(data[user]) < len(dates):
            data[user].insert(0, 0)
    
    log(f"Prepared data for {len(dates)} days and {len(data)} users")
    return dates, data

def generate_graph():
    dates, data = prepare_data()
    
    if not data:
        log("WARNING: No data available")
        return True
    
    try:
        fig, ax = plt.subplots(figsize=(14, 7))
        fig.patch.set_facecolor('white')
        
        colors = plt.cm.Set3(np.linspace(0, 1, len(data)))
        
        for (user, values), color in zip(sorted(data.items()), colors):
            ax.plot(dates, values, marker='o', label=user, 
                   linewidth=2.5, markersize=8, color=color, alpha=0.8)
        
        ax.set_title("Weekly Tailscale Usage (Last 7 Days)", 
                    fontsize=16, fontweight='bold', pad=20)
        ax.set_xlabel("Date", fontsize=12, fontweight='bold')
        ax.set_ylabel("Hours Online", fontsize=12, fontweight='bold')
        
        ax.grid(True, alpha=0.3, linestyle='--', linewidth=0.5)
        ax.set_axisbelow(True)
        ax.yaxis.set_major_locator(MaxNLocator(integer=False))
        
        ax.set_xticks(range(len(dates)))
        ax.set_xticklabels(dates, rotation=45, ha='right')
        ax.legend(loc='best', fontsize=10, framealpha=0.9, edgecolor='black')
        
        plt.tight_layout()
        plt.savefig(OUTPUT_FILE, dpi=100, bbox_inches='tight', facecolor='white')
        log(f"✅ Weekly graph saved: {OUTPUT_FILE}")
        plt.close()
        return True
        
    except Exception as e:
        log(f"ERROR: Failed to generate graph: {e}")
        return False

if __name__ == "__main__":
    if not generate_graph():
        sys.exit(1)
