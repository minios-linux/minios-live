#!/bin/bash

# Update GitHub release notes with content from CHANGES.md
# Usage: update-release-notes.sh <version> [repository]
# Example: update-release-notes.sh v5.0.0
# Example: update-release-notes.sh v5.0.0 minios-linux/minios-live

set -e

VERSION="$1"
REPOSITORY="${2:-$(git remote get-url origin | sed 's|.*/||' | sed 's|\.git$||' | sed 's|.*github.com/||')}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> [repository]"
    echo "Example: $0 v5.0.0"
    echo "Example: $0 v5.0.0 minios-linux/minios-live"
    exit 1
fi

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is required but not installed"
    echo "Please install gh CLI: https://cli.github.com/"
    exit 1
fi

# Check if we're authenticated
if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub CLI"
    echo "Please run: gh auth login"
    exit 1
fi

echo "Extracting release notes for $VERSION from CHANGES.md..."

# Extract release notes using our extraction script
if ! RELEASE_NOTES=$("$SCRIPT_DIR/extract-release-notes.sh" "$VERSION" 2>/dev/null); then
    echo "Error: Could not extract release notes for $VERSION from CHANGES.md"
    exit 1
fi

echo "Release notes extracted successfully!"
echo
echo "Updating GitHub release $VERSION..."

# Update the GitHub release
if gh release edit "$VERSION" --notes "$RELEASE_NOTES" --repo "$REPOSITORY"; then
    echo "Successfully updated release notes for $VERSION"
    echo "View the release at: https://github.com/$REPOSITORY/releases/tag/$VERSION"
else
    echo "Error: Failed to update release $VERSION"
    echo "Make sure the release exists and you have write permissions to the repository"
    exit 1
fi