#!/bin/bash
# Watchdog script to ensure reminders are running
# Monday to Friday is handled in Crontab directly.

DIR="/home/user/monoliths-llm"
JIRA_REMINDER="$DIR/jira-reminder.sh"
OPS360_REMINDER="$DIR/ops360-reminder.sh"

# Ensure Ops360 reminder is executable
chmod +x "$OPS360_REMINDER"

# Check if Ops360 reminder is running
OPS_LOCK="/tmp/ops360_reminder.pid"
if [ -f "$OPS_LOCK" ]; then
    PID=$(cat "$OPS_LOCK")
    if ! ps -p "$PID" >/dev/null 2>&1; then
        rm -f "$OPS_LOCK"
        "$OPS360_REMINDER" &
    fi
else
    "$OPS360_REMINDER" &
fi
