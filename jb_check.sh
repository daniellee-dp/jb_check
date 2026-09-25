#!/bin/bash

# Ensure script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root."
   exit 1
fi

echo "Checking JetBackup status..."

# Check for JetBackup 5
if command -v jetbackup5 &> /dev/null; then
    echo "Status: JetBackup 5 is installed."
    
    LICENSE_OUTPUT=$(jetbackup5 --license 2>&1)
    EXIT_CODE=$?
    
    # JetBackup 5 returns 0 on success and explicitly outputs "License is Valid"
    if [[ $EXIT_CODE -eq 0 ]] && echo "$LICENSE_OUTPUT" | grep -q "License is Valid"; then
        echo "License: Valid"
    else
        echo "License: Invalid or Expired"
        # Extract the specific error line for clarity
        ERROR_MSG=$(echo "$LICENSE_OUTPUT" | grep -i "Error:" | head -n 1)
        if [[ -n "$ERROR_MSG" ]]; then
            echo "Details: $ERROR_MSG"
        else
            echo "Details: $LICENSE_OUTPUT"
        fi
    fi

# Check for JetBackup 4 (Legacy)
elif command -v jetbackup &> /dev/null; then
    echo "Status: JetBackup 4 (Legacy) is installed."
    
    LICENSE_OUTPUT=$(jetbackup --license 2>&1)
    EXIT_CODE=$?
    
    if [[ $EXIT_CODE -eq 0 ]] && echo "$LICENSE_OUTPUT" | grep -qi "valid" && ! echo "$LICENSE_OUTPUT" | grep -qi "invalid"; then
        echo "License: Valid"
    else
        echo "License: Invalid or Expired"
    fi

else
    echo "Status: JetBackup is NOT installed on this server."
fi
