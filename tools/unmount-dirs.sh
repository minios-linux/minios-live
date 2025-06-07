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

unmount_dirs() {
    local DIR_PATH="$1"
    local ATTEMPTS="0"
    local DIR UNMOUNTED
    while true; do
        UNMOUNTED="true"
        if [ "${VERBOSITY_LEVEL}" -ge 1 ]; then
            information "Attempt #${ATTEMPTS} to unmount file systems inside ${DIR_PATH}..."
        fi

        for DIR in $(mount | grep "${DIR_PATH}" | awk '{print $3}' | awk '{print length, $0}' | sort -rn | cut -d' ' -f2-); do
            if [ "${VERBOSITY_LEVEL}" -ge 2 ]; then
                information "Trying to unmount: ${DIR}"
            fi
            if umount "${DIR}" 2>/dev/null; then
                if [ "${VERBOSITY_LEVEL}" -ge 2 ]; then
                    information "Successfully unmounted: ${DIR}"
                fi
            else
                if [ "${VERBOSITY_LEVEL}" -ge 1 ]; then
                    information "Failed to unmount: ${DIR}"
                fi
                UNMOUNTED="false"
            fi
        done
        if [ "${UNMOUNTED}" = "true" ]; then
            if [ "${VERBOSITY_LEVEL}" -ge 1 ]; then
                information "All file systems inside ${DIR_PATH} have been unmounted."
            fi
            break
        fi
        sleep 1
        ATTEMPTS=$(("${ATTEMPTS}" + 1))
        if [ "${ATTEMPTS}" -ge 5 ]; then
            error "Failed to unmount directories after 5 attempts."
            break
        fi
    done

    if [ "${UNMOUNTED}" = "false" ]; then
        error "Failed to unmount all file systems. Unmount file systems inside ${DIR_PATH} manually and try again."
        exit 1
    fi
}

VERBOSITY_LEVEL=0
unmount_dirs "$1"
