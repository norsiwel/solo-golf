#!/bin/bash

# Check for commit message
if [ -z "$1" ]; then
  echo "Usage: ./commit-backup.sh \"Your commit message\""
  exit 1
fi

# Add all changes
git add .

# Commit with message
git commit -m "$1"

# Push to remote
git push

echo "Backup complete 🚀"
