#!/usr/bin/env python3

import os
import requests
import json
import hashlib
from datetime import datetime
from pathlib import Path

# Configuration
WEBHOOK_URL = "<webhook_url>"
STATE_FILE = "/tmp/checkmk_discord_state.log"
DEDUP_WINDOW = 300  # 5-minute deduplication window

def escape_discord(text):
    """Escape special Discord markdown characters"""
    return text.replace('_', r'\_').replace('*', r'\*').replace('~', r'\~') if text else ""

def get_alert_fingerprint():
    """Create unique hash for current alert"""
    return hashlib.md5(f"{os.environ.get('NOTIFY_HOSTNAME','')}_{os.environ.get('NOTIFY_SERVICEDESC','')}_{os.environ.get('NOTIFY_SERVICESTATE','')}".encode()).hexdigest()

def is_duplicate_notification(fingerprint):
    """Check for recent duplicate alerts"""
    try:
        if not Path(STATE_FILE).exists():
            return False

        with open(STATE_FILE, 'r') as f:
            for line in f.readlines():
                stored_fp, timestamp = line.strip().split('|')
                if stored_fp == fingerprint and (datetime.now() - datetime.fromtimestamp(float(timestamp))).seconds < DEDUP_WINDOW:
                    return True
        return False
    except:
        return False

def record_notification(fingerprint):
    """Log sent notifications"""
    with open(STATE_FILE, 'a') as f:
        f.write(f"{fingerprint}|{datetime.now().timestamp()}\n")

def get_custom_message(state):
    """Return state-specific messages with your exact wording"""
    return {
        "OK": {
            "color": 65280,       # Green
            "emoji": "✅",
            "title": "[AWS] Service Recovery",
            "description": "The Windows server services are recovered.",
            "details": "Every services are working correctly.",
            "footer": "System back to normal operation"
        },
        "WARNING": {
            "color": 16776960,    # Yellow
            "emoji": "⚠️",
            "title": "[AWS] Performance Warning",
            "description": "The Windows server services could be slower.",
            "details": "You could have network failure and file access deprecated.",
            "footer": "Investigate when possible"
        },
        "CRITICAL": {
            "color": 16711680,    # Red
            "emoji": "🚨",
            "title": "[AWS] Service Outage",
            "description": "The Windows server services are down.",
            "details": "The network could not work correctly and your file access aren't sure.",
            "footer": "Immediate action required"
        }
    }.get(state, {
        "color": 3553599,        # Gray (default)
        "emoji": "ℹ️",
        "title": "Service Notification",
        "description": f"Service state changed to {state}",
        "details": os.environ.get('NOTIFY_SERVICEOUTPUT', 'No details available'),
        "footer": "CheckMK Monitoring"
    })

try:
    # Deduplication check
    alert_id = get_alert_fingerprint()
    if is_duplicate_notification(alert_id):
        exit(0)

    # Get environment variables
    host = escape_discord(os.environ.get('NOTIFY_HOSTNAME', 'Unknown Server'))
    service = escape_discord(os.environ.get('NOTIFY_SERVICEDESC', 'Windows Services'))
    state = os.environ.get('NOTIFY_SERVICESTATE', 'UNKNOWN')

    # Get custom message configuration
    msg = get_custom_message(state)

    # Prepare Discord embed
    embed = {
        "title": f"{msg['emoji']} {msg['title']} - {host} {msg['emoji']}",
        "color": msg["color"],
        "description": msg["description"],
        "fields": [
            {"name": "🖥️ Server", "value": host, "inline": True},
            {"name": "🔧 Service", "value": service, "inline": True},
            {"name": "📢 Status Update", "value": msg["details"]}
        ],
        "footer": {
            "text": msg["footer"],
            "icon_url": "https://checkmk.com/favicon.ico"
        },
        "timestamp": os.environ.get('NOTIFY_SHORTDATETIME', '')
    }

    # Send to Discord
    response = requests.post(
        WEBHOOK_URL,
        json={"embeds": [embed]},
        headers={"Content-Type": "application/json"},
        timeout=10
    )
    response.raise_for_status()

    # Record successful notification
    record_notification(alert_id)

except Exception as e:
    with open("/tmp/checkmk_discord_errors.log", "a") as f:
        f.write(f"{datetime.now()} - Error: {str(e)}\n")
    raise

# This script has been generated by DeepSeek. 