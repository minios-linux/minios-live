#!/bin/bash

# Check if the current user is root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi

# Function to check if a mount point is mounted
is_mounted() {
    mountpoint -q "$1"
    return $?
}

# Get the path to search for mount points
SEARCH_PATH="${1:-/build/minios-live/build}"

# Get the list of mount points containing the search path and extract the next column after "on"
MOUNT_POINTS=$(mount | grep "$SEARCH_PATH" | awk '{for(i=1;i<=NF;i++) if ($i=="on") print $(i+1)}')

# Sort the mount points in reverse order
MOUNT_POINTS=$(echo "$MOUNT_POINTS" | sort -r)

# Check if there are any mount points to unmount
if [[ -z $MOUNT_POINTS ]]; then
   echo -e "\e[32mNo mount points to unmount.\e[0m"
   exit 0
fi

# Perform unmount iterations until all mount points are unmounted
while [[ ! -z $MOUNT_POINTS ]]; do
    ALL_UNMOUNTED=true

    for MOUNT_POINT in $MOUNT_POINTS; do
        if is_mounted "$MOUNT_POINT"; then
            umount "$MOUNT_POINT" >/dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                echo "Unmounted mount point: $MOUNT_POINT successfully."
            else
                ALL_UNMOUNTED=false
            fi
        fi
    done

    # Update the list of mount points and sort them in reverse order
    MOUNT_POINTS=$(mount | grep "$SEARCH_PATH" | awk '{for(i=1;i<=NF;i++) if ($i=="on") print $(i+1)}')
    MOUNT_POINTS=$(echo "$MOUNT_POINTS" | sort -r)

    if [[ ! -z $MOUNT_POINTS ]]; then
        ALL_UNMOUNTED=false
    fi

    if [[ $ALL_UNMOUNTED == true ]]; then
        echo -e "\e[32mAll mount points have been unmounted.\e[0m"
    fi
done
