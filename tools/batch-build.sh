#!/bin/bash
# Usage: container_build_run [OPTIONS]
# Build and run a software container.
#
# Options:"
#   --distribution         The name of the Linux distribution (e.g., 'buster', 'bullseye'...).
#   --desktop-environment  The name of the desktop environment (e.g., 'xfce').
#   --package-variant      The package variant to use (e.g., 'standard', 'minimum'...).
#   --distribution-arch    The architecture of the distribution (e.g., 'amd64', 'i386').
#   --kernel-bpo           Whether to use backported kernel (e.g., 'true', 'false').
#   --kernel-aufs          Whether to use AUFS patched kernel (e.g., 'true', 'false').
#   --kernel-build-dkms    Whether to build DKMS modules for the kernel (e.g., 'true', 'false').
#   --comp-type            The compression type to use (e.g., 'zstd', 'lz4').
#   --locale               The locale to use (e.g., 'en_US', 'ru_RU').
#   --timezone             The timezone to set in the container (e.g., 'Etc/UTC', 'Europe/Moscow').
#
# Example:"
#   container_build_run --distribution 'buster' --desktop-environment 'xfce' --package-variant 'minimum' --distribution-arch 'amd64' --kernel-type 'livekit-mos' --kernel-bpo 'default' --kernel-aufs 'false' --kernel-build-dkms 'true' --comp-type 'false' --locale 'en_US' --timezone 'Etc/UTC'

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PARENT_DIR="$(dirname $SCRIPT_DIR)"

. $PARENT_DIR/linux-live/minioslib || exit 1
SCRIPT_DIR=$PARENT_DIR

container_engine="docker"

container_build_run --distribution "buster" --desktop-environment "xfce" --package-variant "minimum" --distribution-arch "amd64" --kernel-bpo "true" --kernel-aufs "false" --kernel-build-dkms "false" --comp-type "lz4" --locale "en_US" --timezone "Etc/UTC"

container_build_run --distribution "bullseye" --desktop-environment "xfce" --package-variant "standard" --distribution-arch "amd64" --kernel-bpo "false" --kernel-aufs "false" --kernel-build-dkms "true" --comp-type "zstd" --locale "ru_RU" --timezone "Europe/Moscow"