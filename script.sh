#!/bin/bash

# Variables
USERNAME="your-username"
TOKEN="your-personal-access-token"
MAX_DAYS=45

# Define colors for logging
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to log messages with colors
log() {
    local level=$1
    local message=$2

    case $level in
        "info")
            echo -e "${GREEN}${message}${NC}"
            ;;
        "warn")
            echo -e "${YELLOW}${message}${NC}"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# List of branches to exclude
EXCLUDE_BRANCHES=("main" "master" "develop")

# Function to check if a branch is in the exclude list
is_excluded_branch() {
    local branch=$1
    for excluded_branch in "${EXCLUDE_BRANCHES[@]}"; do
        if [[ "$branch" == "$excluded_branch" ]]; then
            return 0
        fi
    done
    return 1
}

# Fetch repositories for the specified user
log "info" "Fetching repositories for $USERNAME..."
repos=$(curl -s -H "Authorization: token $TOKEN" "https://api.github.com/users/$USERNAME/repos?per_page=100" | jq -r '.[] | .name')

# Process each repository
for repo in $repos; do
    log "info" "Processing repository: $repo"
    git clone "https://$USERNAME:$TOKEN@github.com/$USERNAME/$repo.git"
    cd "$repo" || exit

    branches=$(git branch -r | sed 's/origin\///' | grep -v '\->')
    for branch in $branches; do
        if is_excluded_branch "$branch"; then
            log "warn" "Skipping excluded branch $branch in repository $repo"
            continue
        fi

        last_commit_date=$(git show --no-patch --format=%ci "origin/$branch" | head -n 1)
        branch_age=$((($(date +%s) - $(date -d "$last_commit_date" +%s)) / (60 * 60 * 24)))

        if [[ $branch_age -gt $MAX_DAYS ]]; then
            log "info" "Deleting branch $branch (age: $branch_age days) in repository $repo"
            git push origin --delete "$branch"
        else
            log "warn" "Skipping branch $branch (age: $branch_age days) in repository $repo"
        fi
    done

    cd ..
    rm -rf "$repo"
done
