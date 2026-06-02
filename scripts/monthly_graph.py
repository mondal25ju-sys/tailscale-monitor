#!/usr/bin/env python3

"""
Tailscale Monitor - Monthly Graph Generator
Generates monthly usage bar charts
"""

import json
import sys
from pathlib import Path
from datetime import datetime

try:
    import matplotlib.pyplot as plt
    import numpy as np
except ImportError:
    print("ERROR: matplotlib not installed. Run: pip3 install matplotlib numpy")
    sys.exit(1)

BASE_DIR = Path.home() / "tailscale-monitor" / "data"
MONTHLY_FILE = BASE_DIR / "monthly.json"
OUTPUT_FILE = BASE_DIR / "monthly.png"
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

def load_monthly():
    if not MONTHLY_FILE.exists():
        log("WARNING: monthly.json not found")
        return {}
    
    try:
        with open(MONTHLY_FILE, 'r') as f:
            return json.load(f)
    except:
        log("ERROR: Failed to load monthly.json")
        return {}

def generate_graph():
    monthly = load_monthly()
    
    if not monthly:
        log("WARNING: No monthly data")
        return True
    
    try:
        sorted_data = sorted(monthly.items(), key=lambda x: x[1], reverse=True)
        users = [item[0] for item in sorted_data]
        hours = [item[1] / 3600 for item in sorted_data]
        
        log(f"Generating chart for {len(users)} users")
        
        fig, ax = plt.subplots(figsize=(14, 7))
        fig.patch.set_facecolor('white')
        
        colors = plt.cm.RdYlGn_r(np.linspace(0.2, 0.8, len(users)))
        bars = ax.bar(users, hours, color=colors, edgecolor='black', linewidth=1.5, alpha=0.8)
        
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.1f}h',
                    ha='center', va='bottom', fontsize=11, fontweight='bold')
        
        ax.set_title("Monthly Tailscale Usage", fontsize=16, fontweight='bold', pad=20)
        ax.set_xlabel("User", fontsize=12, fontweight='bold')
        ax.set_ylabel("Hours Online", fontsize=12, fontweight='bold')
        ax.grid(axis='y', alpha=0.3, linestyle='--', linewidth=0.5)
        ax.set_axisbelow(True)
        ax.set_xticklabels(users, rotation=45, ha='right')
        ax.yaxis.set_major_locator(plt.MaxNLocator(integer=False))
        
        if len(hours) > 0:
            avg_hours = np.mean(hours)
            ax.axhline(y=avg_hours, color='red', linestyle='--', linewidth=2, 
                       alpha=0.5, label=f'Average: {avg_hours:.1f}h')
            ax.legend(fontsize=10, loc='upper right')
        
        plt.tight_layout()
        plt.savefig(OUTPUT_FILE, dpi=100, bbox_inches='tight', facecolor='white')
        log(f"✅ Monthly graph saved: {OUTPUT_FILE}")
        plt.close()
        return True
        
    except Exception as e:
        log(f"ERROR: Failed to generate graph: {e}")
        return False

if __name__ == "__main__":
    if not generate_graph():
        sys.exit(1)
