#!/usr/bin/env python3
import datetime
import time
import subprocess
import os
import sys
import logging

"""
Weekend Build Service (v4)
--------------------------
Monitors time and launches a Chromium build in 'st' terminal.
Window: Friday 6 PM - Monday 8 AM.
Ensures only one instance runs at a time.
"""

# --- CONFIGURATION ---
START_DAY = 4   # Friday
START_HOUR = 18 # 18:00
END_DAY = 0     # Monday
END_HOUR = 8    # 08:00

LOG_FILE = "/home/user/monoliths-llm/weekend_build.log"
# We use a unique string in the command to make pgrep easier
UNIQUE_MARKER = "WEEKEND_BUILD_INSTANCE"
TARGET_CMD = f"cd $HOME/chromium-src && export {UNIQUE_MARKER}=1 && dash $HOME/monoliths-llm/init.sh"

# Setup logging
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# Ensure graphical apps can open
if 'DISPLAY' not in os.environ:
    os.environ['DISPLAY'] = ':0'

def is_off_hours():
    now = datetime.datetime.now()
    weekday = now.weekday()
    hour = now.hour

    if (weekday == 4 and hour >= START_HOUR) or (weekday in [5, 6]) or (weekday == 0 and hour < END_HOUR):
        return True
    return False

def is_already_running():
    """Checks if the build process is already active."""
    try:
        # Search for the unique marker in the process environment/command line
        # pgrep -f matches the full command line
        output = subprocess.check_output(["pgrep", "-f", UNIQUE_MARKER])
        pids = output.decode().strip().split('\n')
        # Filter out current process if it matches
        my_pid = str(os.getpid())
        pids = [p for p in pids if p != my_pid]
        
        if pids:
            logging.info(f"Already running with PIDs: {pids}")
            return True
        return False
    except subprocess.CalledProcessError:
        return False

def launch():
    if not is_already_running():
        logging.info("Starting weekend build in st...")
        
        # Wrapped command
        cmd = f"st -e bash -c '{TARGET_CMD}; echo; echo \"Build process finished. Press Enter to close.\"; read'"
        
        try:
            subprocess.Popen(cmd, shell=True, preexec_fn=os.setsid)
            logging.info("Successfully launched terminal.")
        except Exception as e:
            logging.error(f"Launch error: {e}")
    else:
        # Already running
        pass

if __name__ == "__main__":
    logging.info("Weekend Build Checker Started (Interval: 30s)")
    print(">>> Weekend Build Checker Started. Logging to " + LOG_FILE)
    
    try:
        while True:
            if is_off_hours():
                launch()
            
            time.sleep(30) # 30 seconds is plenty
    except KeyboardInterrupt:
        logging.info("Service stopped by user.")
        sys.exit(0)
    except Exception as e:
        logging.critical(f"Unhandled exception: {e}")
        sys.exit(1)
