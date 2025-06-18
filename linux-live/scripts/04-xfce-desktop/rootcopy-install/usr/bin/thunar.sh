#!/bin/bash
# Thunar Locale Configuration Wrapper
# This script checks the system's locale and applies a localized
# Thunar configuration file if available. It then executes the
# original Thunar binary.
# Author: crims0n <https://minios.dev>

if [ "$(echo $LANG | cut -d'_' -f1)" = "pt_BR" ]; then
    LOCALE="br" # Special case for Brazilian Portuguese
elif [ "$(echo $LANG | cut -d'_' -f1)" = "C" ]; then
    LOCALE="en"
else
    LOCALE=$(echo $LANG | cut -d'_' -f1)
fi

SOURCE_FILE=~/.config/Thunar/uca.$LOCALE.xml
TARGET_FILE=~/.config/Thunar/uca.xml

if [ -f "$SOURCE_FILE" ]; then
    if [ ! -f "$TARGET_FILE" ] || ! cmp -s "$SOURCE_FILE" "$TARGET_FILE"; then
        cp "$SOURCE_FILE" "$TARGET_FILE"
    fi
fi

# Check if the system supports aufs
if ! grep -q aufs /proc/filesystems; then
    # Remove specific actions using xmlstarlet
    if command -v xmlstarlet > /dev/null 2>&1; then
        xmlstarlet ed -d '//action[icon="module-connect"]' "$TARGET_FILE" > "$TARGET_FILE.tmp"
        xmlstarlet ed -d '//action[icon="module-disconnect"]' "$TARGET_FILE.tmp" > "$TARGET_FILE"
        rm "$TARGET_FILE.tmp"
    fi
fi

exec /usr/bin/thunar-bin "$@"
