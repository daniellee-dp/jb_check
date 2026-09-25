#!/bin/bash

# Ensure script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root."
   exit 1
fi

echo "Checking JetBackup status..."

# Check for JetBackup 5 (Default / Current Version)
if command -v jetbackup5 &> /dev/null; then
    echo "Status: JetBackup 5 is installed."
    
    # Check license status via JetBackup 5 CLI
    LICENSE_OUTPUT=$(jetbackup5 --license 2>&1)
    
    if echo "$LICENSE_OUTPUT" | grep -qi "valid\|active"; then
        echo "License: Valid"
    else
        echo "License: Invalid or Expired"
        echo "Details: $LICENSE_OUTPUT"
    fi

# Check for JetBackup 4 (Legacy Version)
elif command -v jetbackup &> /dev/null; then
    echo "Status: JetBackup 4 (Legacy) is installed."
    
    # Check license status via JetBackup 4 CLI
    LICENSE_OUTPUT=$(jetbackup --license 2>&1)
    
    if echo "$LICENSE_OUTPUT" | grep -qi "valid\|active"; then
        echo "License: Valid"
    else
        echo "License: Invalid or Expired"
        echo "Details: $LICENSE_OUTPUT"
    fi

else
    echo "Status: JetBackup is NOT installed on this server."
fi
