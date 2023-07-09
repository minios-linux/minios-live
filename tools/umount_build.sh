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
search_path="${1:-/build/minios-live/build}"

# Get the list of mount points containing the search path and extract the next column after "on"
mount_points=$(mount | grep "$search_path" | awk '{for(i=1;i<=NF;i++) if ($i=="on") print $(i+1)}')

# Check if there are any mount points to unmount
if [[ -z $mount_points ]]; then
   echo -e "\e[32mNo mount points to unmount.\e[0m"
   exit 0
fi

# Perform unmount iterations until all mount points are unmounted
while [[ ! -z $mount_points ]]; do
    all_unmounted=true

    for mount_point in $mount_points; do
        if is_mounted "$mount_point"; then
            umount "$mount_point" >/dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                echo "Unmounted mount point: $mount_point successfully."
            else
                all_unmounted=false
            fi
        fi
    done

    # Update the list of mount points
    mount_points=$(mount | grep "$search_path" | awk '{for(i=1;i<=NF;i++) if ($i=="on") print $(i+1)}')

    if [[ ! -z $mount_points ]]; then
        all_unmounted=false
    fi

    if [[ $all_unmounted == true ]]; then
        echo -e "\e[32mAll mount points have been unmounted.\e[0m"
    fi
done
