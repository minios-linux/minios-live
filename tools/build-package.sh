#!/bin/bash

# Determine the current directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Move to the parent directory relative to the tools folder
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Verify that the debian/changelog file exists
if [[ ! -f "$PROJECT_DIR/debian/changelog" ]]; then
    echo "Error: File debian/changelog not found in $PROJECT_DIR"
    exit 1
fi

# Read project name and version from the first header in the changelog
PROJECT_NAME=$(head -n 1 "$PROJECT_DIR/debian/changelog" | awk '{print $1}')
PROJECT_VERSION=$(head -n 1 "$PROJECT_DIR/debian/changelog" | awk -F '[()]' '{print $2}')

if [[ -z "$PROJECT_NAME" || -z "$PROJECT_VERSION" ]]; then
    echo "Error: Failed to determine project name or version from debian/changelog"
    exit 1
fi

# Archive name
ARCHIVE_NAME="${PROJECT_NAME}_${PROJECT_VERSION%%-*}.orig.tar.xz"

# Create a temporary directory for the project copy
TEMP_DIR=$(mktemp -d)

if [[ ! -d "$TEMP_DIR" ]]; then
    echo "Error: Failed to create temporary directory"
    exit 1
fi

# Create a subdirectory inside the temporary directory for the project copy
PROJECT_TEMP_DIR="$TEMP_DIR/${PROJECT_NAME}-${PROJECT_VERSION%%-*}"

mkdir -p "$PROJECT_TEMP_DIR"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to create project directory inside temporary directory"
    exit 1
fi

# Copy project files to the temporary project directory, excluding ignored files and folders
rsync -av --exclude=".git" \
          --exclude=".github" \
          --exclude=".vscode" \
          --exclude="build" \
          --exclude="debian" \
          --exclude="submodules" \
          --exclude="tools/build-package.sh" \
          --exclude=".gitignore" \
          --exclude=".gitmodules" \
          --exclude="CHANGES.md" \
          "$PROJECT_DIR/" "$PROJECT_TEMP_DIR/"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to copy project files to temporary project directory"
    exit 1
fi

# Change to the temporary project directory
cd "$PROJECT_TEMP_DIR" || {
    echo "Error: Failed to switch to temporary project directory"
    exit 1
}

# Run dh_make to create the .orig.tar.xz archive
dh_make -s -c gpl2 -y --createorig

if [[ $? -ne 0 ]]; then
    echo "Error: dh_make failed to create the .orig.tar.xz archive"
    exit 1
fi

# Remove the newly created debian folder
rm -rf "$PROJECT_TEMP_DIR/debian"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to remove temporary debian folder"
    exit 1
fi

# Copy the original debian folder from the project directory
cp -r "$PROJECT_DIR/debian" "$PROJECT_TEMP_DIR/"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to copy original debian folder to temporary project directory"
    exit 1
fi

# Move to the directory containing the orig tarball and the project copy
cd "$PROJECT_TEMP_DIR" || {
    echo "Error: Failed to switch to temporary directory"
    exit 1
}

# Build the package using dpkg-buildpackage
dpkg-buildpackage -us -uc && dpkg-buildpackage -us -uc -Tclean

if [[ $? -eq 0 ]]; then
    echo "Debian package successfully built."
else
    echo "Error building Debian package."
    exit 1
fi

# Inform the user of the location of the generated files
echo "Package files are located in: $TEMP_DIR"

# Do not remove the temporary directory to allow the user to inspect the files
