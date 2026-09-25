#!/bin/bash

# Ensure script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root."
   exit 1
fi

echo "Checking JetBackup status..."

JB_VALID=false

# Check JetBackup 5
if command -v jetbackup5 &> /dev/null; then
    echo "Status: JetBackup 5 is installed."
    LICENSE_OUTPUT=$(jetbackup5 --license 2>&1)
    EXIT_CODE=$?
    
    if [[ $EXIT_CODE -eq 0 ]] && echo "$LICENSE_OUTPUT" | grep -qiE "License is (Active|Valid)" && ! echo "$LICENSE_OUTPUT" | grep -qiE "Invalid|Cancelled"; then
        echo "License: Valid"
        JB_VALID=true
        
        if command -v jetbackup5api &> /dev/null; then
            python3 - << 'EOF' 2>/dev/null
import subprocess

def parse_jb5_info():
    try:
        # 1. Fetch Backup Jobs info
        jobs_res = subprocess.check_output("jetbackup5api -F listBackupJobs", shell=True, stderr=subprocess.DEVNULL).decode('utf-8')
        
        job_name = None
        last_run = None
        
        for line in jobs_res.splitlines():
            line = line.strip()
            if line.startswith("name:"):
                val = line.split(":", 1)[1].strip().strip('"\'')
                if val != "JetBackup Config" and not job_name:
                    job_name = val
            elif (line.startswith("last_run:") or line.startswith("last_execution:")) and not last_run:
                val = line.split(":", 1)[1].strip().strip('"\'')
                if val and val != "0" and val.lower() != "none":
                    last_run = val

        # Fallback to listBackups if last_run is empty
        if not last_run:
            backups_res = subprocess.check_output("jetbackup5api -F listBackups", shell=True, stderr=subprocess.DEVNULL).decode('utf-8')
            for line in backups_res.splitlines():
                if "created:" in line:
                    val = line.split(":", 1)[1].strip().strip('"\'')
                    if val:
                        last_run = val
                        break

        # 2. Fetch Destination Hostname
        dest_res = subprocess.check_output("jetbackup5api -F listDestinations", shell=True, stderr=subprocess.DEVNULL).decode('utf-8')
        dest_host = None
        
        for line in dest_res.splitlines():
            line = line.strip()
            if line.startswith("host:") or line.startswith("hostname:") or line.startswith("server:"):
                val = line.split(":", 1)[1].strip().strip('"\'')
                if val:
                    dest_host = val
                    break

        if last_run:
            print(f"Last Backup Generated: {last_run}")
        else:
            print("Last Backup Generated: No completed backup recorded")

        if job_name:
            print(f"Backup Job Name: {job_name}")

        if dest_host:
            print(f"Destination Hostname: {dest_host}")

    except Exception:
        print("Last Backup Generated: Unable to fetch details")

parse_jb5_info()
EOF
        fi
    else
        echo "License: Invalid or Expired"
    fi

# Check JetBackup 4 (Legacy)
elif command -v jetbackup &> /dev/null; then
    echo "Status: JetBackup 4 (Legacy) is installed."
    LICENSE_OUTPUT=$(jetbackup --license 2>&1)
    EXIT_CODE=$?
    
    if [[ $EXIT_CODE -eq 0 ]] && echo "$LICENSE_OUTPUT" | grep -qiE "License is (Active|Valid)" && ! echo "$LICENSE_OUTPUT" | grep -qiE "Invalid|Cancelled"; then
        echo "License: Valid"
        JB_VALID=true
        
        if command -v jetbackupapi &> /dev/null; then
            JOB_NAME=$(jetbackupapi -F listBackupJobs 2>/dev/null | grep -iE "^\s*name:" | head -n 1 | awk -F ': ' '{print $2}' | tr -d '"'\')
            LAST_BACKUP_TIME=$(jetbackupapi -F listBackups 2>/dev/null | grep -iE "^\s*created:" | head -n 1 | awk -F ': ' '{print $2}' | tr -d '"'\')
            DEST_HOST=$(jetbackupapi -F listDestinations 2>/dev/null | grep -iE "^\s*host:" | head -n 1 | awk -F ': ' '{print $2}' | tr -d '"'\')

            if [[ -n "$LAST_BACKUP_TIME" ]]; then
                echo "Last Backup Generated: $LAST_BACKUP_TIME"
                echo "Backup Job Name: ${JOB_NAME:-N/A}"
                [[ -n "$DEST_HOST" ]] && echo "Destination Hostname: $DEST_HOST"
            else
                echo "Last Backup Generated: No backup history found"
            fi
        fi
    else
        echo "License: Invalid or Expired"
    fi

else
    echo "Status: JetBackup is NOT installed on this server."
fi

# Fallback: Check Backuply if JetBackup is missing or its license is invalid
if [[ "$JB_VALID" = false ]]; then
    echo "-----------------------------------"
    echo "Checking Backuply status..."
    
    if [[ -x "/usr/local/backuply/bin/backuply" ]] || [[ -d "/usr/local/backuply" ]]; then
        echo "Backuply Status: Installed"
        
        # Determine last backup generation date
        if [[ -d "/var/backuply/logs" ]]; then
            LAST_LOG=$(ls -t /var/backuply/logs/*.log 2>/dev/null | head -n 1)
            if [[ -n "$LAST_LOG" ]]; then
                LAST_TIME=$(date -r "$LAST_LOG" "+%Y-%m-%d %H:%M:%S")
                echo "Last Backup Generated: $LAST_TIME"
            else
                echo "Last Backup Generated: No log files found in /var/backuply/logs"
            fi
        elif [[ -d "/var/backuply/backups" ]]; then
            LAST_BACKUP=$(ls -t /var/backuply/backups/ 2>/dev/null | head -n 1)
            if [[ -n "$LAST_BACKUP" ]]; then
                LAST_TIME=$(date -r "/var/backuply/backups/$LAST_BACKUP" "+%Y-%m-%d %H:%M:%S")
                echo "Last Backup Generated: $LAST_TIME"
            else
                echo "Last Backup Generated: Backup directory is empty"
            fi
        else
            echo "Last Backup Generated: No backup history directory found in /var/backuply"
        fi
    else
        echo "Backuply Status: NOT installed"
    fi
fi
