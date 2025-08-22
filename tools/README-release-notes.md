# Release Notes Management Tools

This directory contains tools for managing release notes extraction and updates from the CHANGES.md file.

## Scripts

### extract-release-notes.sh

Extracts release notes for a specific version from CHANGES.md.

**Usage:**
```bash
./extract-release-notes.sh <version>
```

**Examples:**
```bash
./extract-release-notes.sh v5.0.0
./extract-release-notes.sh v4.1.2
```

The script will output the release notes content for the specified version to stdout. If the version is not found, it will exit with an error.

### update-release-notes.sh

Updates the GitHub release notes for a specific version using content extracted from CHANGES.md.

**Prerequisites:**
- GitHub CLI (`gh`) must be installed and authenticated
- Write access to the repository

**Usage:**
```bash
./update-release-notes.sh <version> [repository]
```

**Examples:**
```bash
# Update release notes for current repository
./update-release-notes.sh v5.0.0

# Update release notes for specific repository
./update-release-notes.sh v5.0.0 minios-linux/minios-live
```

## Workflow Integration

The release workflow (`.github/workflows/release.yml`) has been updated to automatically extract release notes from CHANGES.md when creating new releases. If release notes are found for the specified version, they will be used. Otherwise, default release notes will be generated.

## CHANGES.md Format

The scripts expect the CHANGES.md file to follow this format:

```markdown
## v5.0.0

Release content here...

## v4.1.2

Another release content...
```

The version header should be at the beginning of a line and start with `## v` or `## ` followed by the version number.