#!/bin/bash

# Check if filename is provided
if [ -z "$1" ]; then
    echo "Please provide a filename as an argument."
    exit 1
fi

# Check if operation mode is provided
if [ -z "$2" ]; then
    echo "Please provide an operation mode (replace or append) as the second argument."
    exit 1
fi

# Get FILENAME without extension for the .pot file
FILENAME=$(basename -- "$1")
EXTENSION="${FILENAME##*.}"
FILENAME="${FILENAME%.*}"

# Define .pot file
POT_FILE="${FILENAME}.pot"

# operation mode
MODE="$2"

# Create an empty .pot file for replace mode
if [ "$MODE" == "replace" ]; then
    >"$POT_FILE"
elif [ "$MODE" == "append" ]; then
    if [ ! -f "$POT_FILE" ]; then
        touch "$POT_FILE"
    fi
else
    echo "Invalid operation mode. Only 'replace' or 'append' are allowed."
    exit 1
fi

# Extract lines for translation
grep -Pno '(?<=\()[^\)]+' "$1" | while read -r LINE; do
    LINENO="${LINE%%:*}"
    TEXT="${LINE#*:}"
    # Remove quotes and parentheses, add lines to the .POT file
    echo "#: $1:$LINENO" >>"$POT_FILE"
    echo "msgid \"$TEXT\"" >>"$POT_FILE"
    echo "msgstr \"\"" >>"$POT_FILE"
    echo "" >>"$POT_FILE"
done
