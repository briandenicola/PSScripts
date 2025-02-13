#!/bin/bash

# Ensure GitHub CLI is authenticated
if ! gh auth status &>/dev/null; then
  echo "Error: GitHub CLI authentication failed. Please login using 'gh auth login'."
  exit 1
fi

# Fetch all repositories you own that are NOT forks, and retrieve their SSH URLs
echo "Fetching repositories you own (excluding forks)..."
OWNED_REPOS=$(gh repo list --json name,sshUrl,isFork --jq '.[] | select(.isFork | not) | {name: .name, sshUrl: .sshUrl}')

# Check if any repositories exist
if [[ -z "$OWNED_REPOS" ]]; then
  echo "No owned repositories found."
  exit 0
fi

# Loop through each repository and clone it if needed
echo "$OWNED_REPOS" | while IFS= read -r REPO_JSON; do
  REPO_NAME=$(echo "$REPO_JSON" | jq -r '.name')
  REPO_SSH_URL=$(echo "$REPO_JSON" | jq -r '.sshUrl')

  if [[ -d "$REPO_NAME" ]]; then
    echo "Repository '$REPO_NAME' is already cloned locally. Skipping..."
  else
    echo "Cloning repository '$REPO_NAME' via $REPO_SSH_URL..."
    git clone "$REPO_SSH_URL" "$REPO_NAME"
  fi
done

echo "All repositories are up to date."