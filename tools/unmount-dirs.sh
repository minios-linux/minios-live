#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: $0 <directory_path> - Provide the directory path for unmounting file systems."
    exit 1
fi

error() {
    echo "E: $1" >&2
}

information() {
    echo "I: $1"
}

warning() {
    echo "W: $1"
}

# Function to unmount all file systems under a given directory
# Parameters:
#   $1 - Absolute or relative path to the directory
unmount_dirs() {
    # Get the directory path from argument and normalize to absolute
    local DIR_PATH="$(realpath -m "$1")"
    local MOUNTS
    local FAILED=0

    # 1) Collect all mount points strictly inside DIR_PATH (deepest first)
    mapfile -t MOUNTS < <(
        findmnt -rn -o TARGET |
            while read -r TARGET; do
                TARGET_ABS="$(realpath -m "$TARGET")"
                if [[ "$TARGET_ABS" == "$DIR_PATH"/* ]]; then
                    echo "$TARGET_ABS"
                fi
            done |
            # Sort by path length descending to unmount deepest first
            awk '{ print length, $0 }' |
            sort -rn |
            cut -d' ' -f2-
    )

    if [ "${#MOUNTS[@]}" -eq 0 ]; then
        information "No mount points found under ${DIR_PATH}."
        return 0
    fi

    # 2) Attempt to unmount each mount point (without killing processes)
    for MOUNT in "${MOUNTS[@]}"; do
        if [ ${VERBOSITY_LEVEL:-1} -ge 2 ]; then
            information "Processing mount point: ${MOUNT}"
            information "Attempting to unmount ${MOUNT}..."
        fi

        if umount "${MOUNT}" 2>/dev/null; then
            information "Successfully unmounted ${MOUNT}."
        else
            error "Could not unmount ${MOUNT}."
            ((FAILED++))
        fi
    done

    # 3) Final status report
    if [ "$FAILED" -gt 0 ]; then
        error "Failed to unmount ${FAILED} mount point(s). Remaining mounted:"
        for MOUNT in "${MOUNTS[@]}"; do
            if mountpoint -q "${MOUNT}"; then
                warning "  * ${MOUNT}"
            fi
        done
        return 1
    fi

    information "All file systems under ${DIR_PATH} have been successfully unmounted."
    return 0
}

VERBOSITY_LEVEL=0
unmount_dirs "$1"
