% CONDINAPT(1) CondinAPT Package Manager
% MiniOS Development Team
% October 2025

# NAME

condinapt - conditional package installation tool for Debian-like systems

# SYNOPSIS

**condinapt** [*OPTIONS*]

# DESCRIPTION

**CondinAPT** is a versatile tool for automating package installation in any Debian-like system (Debian, Ubuntu, and their derivatives). Its key feature is the ability to define complex conditions and rules for installing each package based on arbitrary system configurations.

## Areas of Application

- Linux distribution build systems
- Automation of server and workstation setup
- Deployment of various system configurations
- Package management in Docker containers
- CI/CD pipelines for environment setup
- Creation of custom installation images

## Key Features

- **Conditional Installation:** Install packages based on flexible filters (+, -)
- **External Configuration:** Complete separation of logic (package list) from data (system parameters)
- **Installation Queues:** Divide the process into sequential stages to resolve dependencies
- **Priority Queue:** Guaranteed installation of critical packages first
- **Complex Logic:** Support for "AND" (&&), "OR" (||) operators, as well as group filters (+{a|b}, -{a&b})
- **Readability:** Support for comments and empty lines to structure lists
- **Backward Compatibility:** Supports simple package lists without conditions

# OPTIONS

**-l**, **\-\-package-list** *PATH*
:   (Required) Path to the package list file

**-c**, **\-\-config** *PATH*
:   (Required) Path to the main configuration file

**-m**, **\-\-filter-mapping** *PATH*
:   (Optional) Path to the filter mapping file

**-P**, **\-\-priority-list** *PATH*
:   (Optional) Path to the priority package list file

**-s**, **\-\-simulation**
:   Simulation mode. Packages will not be installed

**-C**, **\-\-check-only**
:   Only check if packages are already installed

**-v**, **\-\-verbose**
:   Verbose output

**-vv**, **\-\-very-verbose**
:   Very verbose output

**-x**, **\-\-xtrace**
:   Enable **set -x** command tracing

**-f**, **\-\-force**
:   Force apt cache update (apt update)

**-h**, **\-\-help**
:   Show help

# CORE COMPONENTS

CondinAPT operates with four key files:

## condinapt script
The core, containing all processing logic

## Main configuration file (-c)
A file with bash variables describing the current environment

Example (**system.conf**):

    DISTRIBUTION="bookworm"
    SYSTEM_TYPE="server"
    ENVIRONMENT="production"
    LOCALE="en_US"
    FEATURES="web,database"

## Filter mapping file (-m)
Links short prefixes (used in the package list) to variable names from the main configuration file. This file is **optional**. If a filter is not present in the filter mapping file, it will be used as a variable name from the main configuration file. If the variable is not found, CondinAPT will declare it empty.

Example (**filters.map**):

    d=DISTRIBUTION
    st=SYSTEM_TYPE
    env=ENVIRONMENT
    arch=ARCHITECTURE
    feat=FEATURES

## Package list file (-l)
The main file describing what to install and under what conditions

# PACKAGE LIST SYNTAX

Each line in the package list file consists of two main parts:

1. Package name with optional version and release specification
2. Condition filters - define the conditions under which the package will be installed

## Package Name Structure

**Simple name:**

    vim

**Package version:**

- **package=version** - loose version requirement. If the required version is unavailable, an available version is installed
- **package==version** - strict requirement. If the version is not found, installation aborts with an error

**Release specification:**

The release is specified using the **@** symbol:

    telegram@bookworm-backports
    kernel-image-6.5.0@trixie-backports

## File Structure

- **Package names:** Each package or condition is written on a new line
- **Comments:** Lines starting with **#**, or text after **#** on a line, are completely ignored
- **Empty lines:** Ignored and serve for visual separation

## Filters and Conditions

### Single Filters

**+ (Positive):** The condition is true if the variable value **matches**

Format: **+<prefix>=<value>**

Example:

    nginx +st=server

**- (Negative):** The condition is true if the variable value **does not match**

Format: **-<prefix>=<value>**

Example:

    monitoring-tools -st=desktop

### Group Filters

**+{a|b} (OR for inclusion):** True if **at least one** of the conditions in the group is true

    web-server +{st=server|st=web-server}

**+{a&b} (AND for inclusion):** True only if **all** conditions in the group are true

    database-tools +{d=bookworm&st=server}

**-{a|b} (OR for exclusion):** The package is excluded if **at least one** of the conditions is true

    debug-tools -{env=production|st=minimal}

**-{a&b} (AND for exclusion):** The package is excluded only if **all** conditions are true

    development-tools -{env=production&st=minimal}

### Logical Operators

**|| (OR / Fallback):** Try to install the left part. If it fails, try the right part

    exfatprogs -d=bookworm || exfat-utils

**&& (AND / Conjunction):** All parts must successfully pass filter checks

    nginx +st=web-server && php-fpm

### Special Modifiers

**! (Mandatory Package):** If a package is marked with **!**, but cannot be found in repositories, CondinAPT will abort execution with an error

    !essential-package

**@ (Release Specification):** Install a package from a specific Debian/Ubuntu release

    kernel-image-6.5.0 @trixie-backports

## Installation Queues

The **---** separator on a separate line divides the list into groups (queues). Packages from one queue are installed together in a single apt call. Queues are executed strictly sequentially.

Example:

    # Queue 1: Base system
    systemd
    network-manager
    ---
    # Queue 2: Web server
    nginx
    php-fpm
    ---
    # Queue 3: Monitoring
    prometheus

## Priority Queue

Packages listed in the file specified by the **-P** flag (one package per line, no filters) form a special "Queue #1", which is executed first.

Any package from the priority list is automatically removed from all regular queues. This ensures it will be installed unconditionally.

# EXAMPLES

## Quick Start

Create the configuration file **config.conf**:

    DISTRIBUTION="bookworm"
    SYSTEM_TYPE="server"
    ENVIRONMENT="production"

Create the package list **packages.list**:

    # Base packages - always installed
    vim
    curl

    # Packages only for servers
    nginx +SYSTEM_TYPE=server
    mysql-server +SYSTEM_TYPE=server

    # Exclude packages for production environment
    debug-tools -ENVIRONMENT=production

Run the installation:

    condinapt -l packages.list -c config.conf

Or test in simulation mode:

    condinapt -l packages.list -c config.conf -s

## Multimedia Server

**packages.list:**

    # Basic multimedia codecs - always
    gstreamer1.0-plugins-base
    gstreamer1.0-plugins-good

    # Additional codecs - not for minimal installation
    gstreamer1.0-plugins-bad -st=minimal
    gstreamer1.0-plugins-ugly -st=minimal

    # Professional tools - only for full configuration
    ffmpeg +st=media-server
    vlc +st=media-server
    ---
    # Distribution-specific packages from backports
    ffmpeg @bookworm-backports +d=bookworm

## Web Server with Various Configurations

**packages.list:**

    # Basic web server components
    nginx
    openssl

    # Database - only for full installations
    mysql-server +st=full-server -{env=minimal}
    postgresql +st=database-server

    # PHP - for web servers
    php-fpm +feat=php
    php-mysql +{feat=php&st=full-server}

    # Monitoring - not for development
    prometheus-node-exporter -env=development

# OPERATING MODES

## Simulation Mode

Allows you to see which packages will be installed without actually installing them:

    condinapt -l packages.list -c system.conf -s

In simulation mode, the script exits with exit code 1.

## Check Mode

Checks which packages from the list are already installed on the system:

    condinapt -l packages.list -c system.conf -C

Shows errors for uninstalled packages and returns exit code 1 if there are uninstalled packages.

## Debugging Modes

**Verbose Output (-v):**

Shows detailed information about filter checks and displays results for each package.

**Very Verbose Output (-vv):**

Maximum process detail, shows all intermediate steps.

**Command Tracing (-x):**

Enables **set -x** for script debugging, shows each command being executed.

# ERROR HANDLING

## Mandatory Packages

If a package is marked as mandatory (**!**) but not found in repositories, CondinAPT:

1. Outputs an error message
2. Aborts execution (unless in simulation mode)
3. Returns exit code 1

## Handling Unavailable Versions

**Loose Versions (=):**

If the exact version is unavailable, any available version is installed with a warning.

**Strict Versions (==):**

If the exact version is unavailable, the package is skipped. If the package is mandatory (**!**), execution aborts.

## Version Holding

CondinAPT automatically applies **apt-mark hold** when the exactly requested version was installed, preventing automatic updates.

# FILES

**/etc/condinapt/config.conf**
:   Default configuration file

**/etc/condinapt/filters.map**
:   Default filter mapping file

# SEE ALSO

**apt**(8), **apt-get**(8), **apt-cache**(8), **condinapt-minios**(7)

# AUTHORS

MiniOS Development Team <https://minios.dev>
