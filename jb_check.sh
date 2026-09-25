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
    
    if [[ $EXIT_CODE -eq 0 ]] && echo "$LICENSE_OUTPUT" | grep -q "License is Valid"; then
        echo "License: Valid"
        JB_VALID=true
    else
        echo "License: Invalid or Expired"
    fi

# Check JetBackup 4 (Legacy)
elif command -v jetbackup &> /dev/null; then
    echo "Status: JetBackup 4 (Legacy) is installed."
    LICENSE_OUTPUT=$(jetbackup --license 2>&1)
    EXIT_CODE=$?
    
    if [[ $EXIT_CODE -eq 0 ]] && echo "$LICENSE_OUTPUT" | grep -qi "valid" && ! echo "$LICENSE_OUTPUT" | grep -qi "invalid"; then
        echo "License: Valid"
        JB_VALID=true
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
    
    # Check for Backuply CLI binary or installations directory
    if [[ -x "/usr/local/backuply/bin/backuply" ]] || [[ -d "/usr/local/backuply" ]]; then
        echo "Backuply Status: Installed"
        
        # Check for backup logs/metadata in /var/backuply
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
