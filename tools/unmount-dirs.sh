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

    # Change to a safe directory to avoid CWD blocking unmount
    cd / 2>/dev/null || true

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
        if [ ${VERBOSITY_LEVEL:-1} -ge 2 ]; then
            information "No mount points found under ${DIR_PATH}."
        fi
        return 0
    fi

    local MAX_PASSES=3
    local PASS=1
    local TO_UNMOUNT=("${MOUNTS[@]}")

    while [ "$PASS" -le "$MAX_PASSES" ] && [ "${#TO_UNMOUNT[@]}" -gt 0 ]; do
        if [ ${VERBOSITY_LEVEL:-1} -ge 2 ]; then
            information "Pass $PASS: attempting to unmount ${#TO_UNMOUNT[@]} point(s)..."
        fi
        local NEXT=()
        for MOUNT in "${TO_UNMOUNT[@]}"; do
            if [ ${VERBOSITY_LEVEL:-1} -ge 2 ]; then
                information "Processing ${MOUNT} (pass $PASS)"
            fi

            # Check if mount point is still mounted before attempting to unmount
            if findmnt "${MOUNT}" >/dev/null 2>&1; then
                if umount "${MOUNT}" 2>/dev/null; then
                    if [ ${VERBOSITY_LEVEL:-1} -ge 2 ]; then
                        information "Successfully unmounted ${MOUNT}."
                    fi
                else
                    # Double-check if it's still mounted after failed umount
                    # (it might have been unmounted by another process between checks)
                    if findmnt "${MOUNT}" >/dev/null 2>&1; then
                        if [ ${VERBOSITY_LEVEL:-1} -ge 2 ]; then
                            warning "Could not unmount ${MOUNT} on pass $PASS; will retry."
                        fi
                        NEXT+=("${MOUNT}")
                    else
                        if [ ${VERBOSITY_LEVEL:-1} -ge 2 ]; then
                            information "Mount point ${MOUNT} was unmounted between checks, skipping."
                        fi
                    fi
                fi
            else
                if [ ${VERBOSITY_LEVEL:-1} -ge 2 ]; then
                    information "Mount point ${MOUNT} is already unmounted, skipping."
                fi
            fi
        done
        TO_UNMOUNT=("${NEXT[@]}")
        ((PASS++))

        # Add a delay between passes to allow processes to release resources
        if [ "$PASS" -le "$MAX_PASSES" ] && [ "${#TO_UNMOUNT[@]}" -gt 0 ]; then
            sleep 1
        fi
    done

    # If still unable to unmount after MAX_PASSES, try lazy unmount as a last resort
    if [ "${#TO_UNMOUNT[@]}" -gt 0 ]; then
        if [ ${VERBOSITY_LEVEL:-1} -ge 2 ]; then
            warning "Attempting lazy unmount for remaining ${#TO_UNMOUNT[@]} point(s)..."
        fi
        local LAZY_FAILED=()
        for MOUNT in "${TO_UNMOUNT[@]}"; do
            if findmnt "${MOUNT}" >/dev/null 2>&1; then
                if umount -l "${MOUNT}" 2>/dev/null; then
                    if [ ${VERBOSITY_LEVEL:-1} -ge 2 ]; then
                        information "Successfully lazy-unmounted ${MOUNT}."
                    fi
                else
                    LAZY_FAILED+=("${MOUNT}")
                fi
            fi
        done

        if [ "${#LAZY_FAILED[@]}" -gt 0 ]; then
            error "Failed to unmount ${#LAZY_FAILED[@]} point(s) even with lazy unmount. Remaining:"
            for M in "${LAZY_FAILED[@]}"; do
                warning "  * ${M}"
            done
            return 1
        fi
    fi

    if [ ${VERBOSITY_LEVEL:-1} -ge 2 ]; then
        information "All file systems under ${DIR_PATH} have been successfully unmounted."
    fi
    return 0
}

VERBOSITY_LEVEL=${VERBOSITY_LEVEL:-0}
unmount_dirs "$1"
