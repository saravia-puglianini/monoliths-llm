#!/bin/bash
# Watchdog script to ensure reminders are running
# Monday to Friday is handled in Crontab directly.

DIR="/home/user/monoliths-llm"
JIRA_REMINDER="$DIR/jira-reminder.sh"
OPS360_REMINDER="$DIR/ops360-reminder.sh"

# Ensure they are executable
chmod +x "$JIRA_REMINDER" "$OPS360_REMINDER"

# Check if Jira reminder is running
JIRA_LOCK="/tmp/jira_reminder.pid"
if [ -f "$JIRA_LOCK" ]; then
    PID=$(cat "$JIRA_LOCK")
    if ! ps -p "$PID" >/dev/null 2>&1; then
        rm -f "$JIRA_LOCK"
        "$JIRA_REMINDER" &
    fi
else
    "$JIRA_REMINDER" &
fi

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
