#!/bin/bash
# Script to run reminders every 5 seconds for 1 minute
# Monday to Friday is handled in Crontab directly.

# Paths to the reminder scripts
DIR="/home/user/monoliths-llm"
JIRA_REMINDER="$DIR/jira-reminder.sh"
OPS360_REMINDER="$DIR/ops360-reminder.sh"

# Ensure they are executable
chmod +x "$JIRA_REMINDER" "$OPS360_REMINDER"

# Loop for 1 minute (12 * 5 seconds = 60 seconds)
for i in {1..12}; do
    # Run in background so they don't block the next 5-second tick
    # The lockfiles inside the scripts will prevent multiple dialogs
    "$JIRA_REMINDER" &
    "$OPS360_REMINDER" &
    
    # Tick every 5 seconds
    sleep 5
done
