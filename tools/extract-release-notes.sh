#!/bin/bash

# Extract release notes from CHANGES.md for a specific version
# Usage: extract-release-notes.sh <version>
# Example: extract-release-notes.sh v5.0.0

set -e

VERSION="$1"
CHANGES_FILE="CHANGES.md"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 v5.0.0"
    exit 1
fi

if [ ! -f "$CHANGES_FILE" ]; then
    echo "Error: $CHANGES_FILE not found"
    exit 1
fi

# Remove 'v' prefix if present for searching in the changelog
VERSION_NUMBER="${VERSION#v}"

# Extract the release notes for the specified version
# Find the section starting with "## v$VERSION_NUMBER" or "## $VERSION_NUMBER"
# and continue until the next "## " section or end of file
awk -v version="$VERSION_NUMBER" '
BEGIN { found = 0; printing = 0 }

# Match version header
/^## / {
    if ($2 == "v" version || $2 == version) {
        found = 1
        printing = 1
        next
    } else if (printing) {
        # Found next version, stop printing
        printing = 0
        exit
    }
}

# Print content if we are in the right section
printing && !/^## / {
    print
}

END {
    if (!found) {
        print "Error: Version " version " not found in " FILENAME > "/dev/stderr"
        exit 1
    }
}
' "$CHANGES_FILE"