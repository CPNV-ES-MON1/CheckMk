#!/usr/bin/env python3

import os
import requests
import json
from datetime import datetime
from pathlib import Path

# Configuration
GLPI_API_URL = "<apirest_url>"
APP_TOKEN = "<app_token>"
USER_TOKEN = "<user_token>"
STATE_FILE = "/tmp/glpi_ticket_state.json"

# Util: Read existing state (open tickets)
def read_state():
    if Path(STATE_FILE).exists():
        with open(STATE_FILE, "r") as f:
            return json.load(f)
    return {}

# Util: Save ticket state
def write_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)

# Open GLPI API session
def open_session():
    res = requests.get(
        f"{GLPI_API_URL}/initSession",
        headers={"Authorization": f"user_token {USER_TOKEN}", "App-Token": APP_TOKEN}
    )
    res.raise_for_status()
    return res.json()["session_token"]

# Kill GLPI session
def close_session(session_token):
    requests.get(
        f"{GLPI_API_URL}/killSession",
        headers={"App-Token": APP_TOKEN, "Session-Token": session_token}
    )

# Create new ticket with ITIL category set to "CPU Overload" (ID 698)
def create_ticket(session_token, host, service, state, output):
    payload = {
        "input": {
            "name": f"{state} on {host}",
            "content": f"Issue with service '{service}' on host '{host}'\n\nDetails: {output}",
            "status": 1,         # New
            "priority": 3,       # Medium
            "urgency": 2,
            "impact": 2,
            "type": 1,           # Incident
            "requesttypes_id": 1,
            "itilcategories_id": 698  # CPU Overload category
        }
    }
    res = requests.post(
        f"{GLPI_API_URL}/Ticket",
        headers={
            "Content-Type": "application/json",
            "App-Token": APP_TOKEN,
            "Session-Token": session_token
        },
        json=payload,
        timeout=10
    )
    res.raise_for_status()
    return res.json()["id"]

# Close existing ticket
def close_ticket(session_token, ticket_id):
    payload = {
        "input": {
            "id": ticket_id,
            "status": 6  # Solved
        }
    }
    res = requests.put(
        f"{GLPI_API_URL}/Ticket/{ticket_id}",
        headers={
            "Content-Type": "application/json",
            "App-Token": APP_TOKEN,
            "Session-Token": session_token
        },
        json=payload,
        timeout=10
    )
    res.raise_for_status()

# Main logic
def main():
    host = os.environ.get("NOTIFY_HOSTNAME", "Unknown")
    service = os.environ.get("NOTIFY_SERVICEDESC", "Service")
    state = os.environ.get("NOTIFY_SERVICESTATE", "UNKNOWN")
    output = os.environ.get("NOTIFY_SERVICEOUTPUT", "No output")

    fingerprint = f"{host}_{service}"
    state_data = read_state()

    session = open_session()

    try:
        if state in ["CRITICAL", "WARNING"]:
            if fingerprint not in state_data:
                ticket_id = create_ticket(session, host, service, state, output)
                state_data[fingerprint] = ticket_id
                print(f"Created ticket {ticket_id} for {fingerprint}")
        elif state == "OK":
            if fingerprint in state_data:
                ticket_id = state_data[fingerprint]
                close_ticket(session, ticket_id)
                print(f"Closed ticket {ticket_id} for {fingerprint}")
                del state_data[fingerprint]
    finally:
        close_session(session)
        write_state(state_data)

if __name__ == "__main__":
    main()