#!/bin/bash

# Ensure GitHub CLI is authenticated
if ! gh auth status &>/dev/null; then
  echo "Error: GitHub CLI authentication failed. Please login using 'gh auth login'."
  exit 1
fi

# Get a list of all archived repositories
echo "Fetching archived repositories..."
ARCHIVED_REPOS=$(gh repo list --archived --json name --jq '.[].name')

# Check if any archived repositories exist
if [[ -z "$ARCHIVED_REPOS" ]]; then
  echo "No archived repositories found."
  exit 0
fi

# Loop through each archived repository
for REPO in $ARCHIVED_REPOS; do
  if [[ -d "$REPO/.git" ]]; then  
    echo "Removing .git directory from: $REPO"
    rm -rf "$REPO/.git"
  else
    echo "$REPO is not cloned locally or does not contain a .git directory."
  fi
done

echo "Clean-up completed."