% CONDINAPT(1) Conditional APT Package Installer
% MiniOS Development Team
% September 2026

# NAME

condinapt - plan and install APT packages from a conditional package list

# SYNOPSIS

**condinapt** **-l** *PACKAGE-LIST* **-c** *CONFIG* [*OPTIONS*]

# DESCRIPTION

**condinapt** reads a Bash configuration and a package list, evaluates package filters, checks package availability, groups selected packages into APT transactions, and installs them. It supports exact or fallback versions, target releases, alternatives, conjunctions, mandatory alternatives, queue separators, and a priority list.

The configuration file is sourced as Bash and must be trusted. Package installation and any APT list refresh normally require suitable privileges.

# OPTIONS

**-l**, **\-\-package-list** *PATH*
:   Required package list.

**-c**, **\-\-config** *PATH*
:   Required Bash configuration file containing filter variables.

**-m**, **\-\-filter-mapping** *PATH*
:   Optional prefix-to-variable mapping. Without it, filter prefixes are interpreted directly as variable names.

**-P**, **\-\-priority-list** *PATH*
:   Optional file containing one Bash regular expression per line. Expressions match the first package token on each package-list line. Matching lines are moved to priority queues with their filters and target releases preserved.

**-C**, **\-\-check-only**
:   Evaluate filters and report relevant package names that are not installed. Return 1 and print a suggested **apt install** command when packages are missing. This mode checks package names only; it does not validate requested versions or target releases. An alternative expression is satisfied when one branch is installed; if none is installed, every failed branch may be reported and suggested.

**-s**, **\-\-simulation**
:   Plan the installation without installing packages. Simulation always exits with status 1. It may still run **apt-get update** when the package cache is absent or **\-\-force** is used.

**-f**, **\-\-force**
:   Run **apt-get update** before normal installation or simulation even when **/var/cache/apt/pkgcache.bin** exists. It has no effect in check-only mode.

**-v**, **\-\-verbose**
:   Show filter decisions and direct APT output.

**-vv**, **\-\-very-verbose**
:   Show additional planning and priority-queue details.

**-x**, **\-\-xtrace**
:   Enable Bash command tracing.

**-h**, **\-\-help**
:   Display help and exit.

# INPUT FILES

## Configuration

The required configuration is a Bash file. Scalar values compare by exact string equality. Indexed Bash arrays match when any element equals the requested value.

    DISTRIBUTION="bookworm"
    SYSTEM_TYPE="server"
    ENVIRONMENT="production"
    FEATURES=(web database)

## Filter Mapping

An optional mapping assigns short package-list prefixes to configuration variables:

    d=DISTRIBUTION
    st=SYSTEM_TYPE
    env=ENVIRONMENT
    feat=FEATURES

An unmapped prefix is used as the variable name. Missing variables have an empty value. Variable names must be valid Bash identifiers.

## Package List

Each non-empty, non-comment line contains a package expression. Text after **#** is ignored.

    vim
    nginx +st=server
    debug-tools -env=production

## Priority List

Each non-empty, non-comment line is a Bash **=~** regular expression matched against the first package token in a package expression:

    ^linux-.*
    ^firmware-.*
    ^dkms$

# PACKAGE SYNTAX

## Versions

**package=version**
:   Request an exact version. If it is unavailable but another candidate exists, install the candidate and emit a warning.

**package==version**
:   Require an exact version during planning. If it is unavailable, this expression cannot be selected.

When an exact requested version is selected and installed, **condinapt** applies **apt-mark hold** to that package.

## Target Releases

Append **@release** to install through **apt-get -t release**:

    linux-image-amd64 @bookworm-backports

Entries for the same release are pooled into one release-specific queue. The **---** separator does not split target-release queues.

## Filters

**+prefix=value**
:   Include the package when the mapped scalar equals *value* or an array contains it.

**-prefix=value**
:   Exclude the package when the mapped scalar equals *value* or an array contains it.

Repeated positive filters with the same prefix are alternatives. Positive filters with different prefixes must each have at least one match:

    editor +d=bookworm +d=trixie +st=desktop

The example selects Debian Bookworm or Trixie and also requires **SYSTEM_TYPE=desktop**.

Group filters make the relationship explicit:

**+{a|b}**
:   Include when at least one condition matches.

**+{a&b}**
:   Include only when every condition matches.

**-{a|b}**
:   Exclude when at least one condition matches.

**-{a&b}**
:   Exclude only when every condition matches.

Examples:

    web-server +{st=server|st=web-server}
    database-tools +{d=bookworm&st=server}
    debug-tools -{env=production|st=minimal}

## Alternatives And Conjunctions

**left || right**
:   During planning, select the first alternative whose filters pass and whose required packages are installed or available from APT. It is not a runtime fallback: if the later **apt-get install** transaction fails, another alternative is not tried.

**left && right**
:   Require every expression in the alternative to pass filtering and availability checks before adding them to the same installation plan.

**&&** binds within each **||** alternative:

    exfatprogs || exfat-utils && exfat-fuse

## Mandatory Alternatives

A leading **!** marks the entire package expression as mandatory:

    !essential-package
    !preferred-package || fallback-package

If no alternative can be selected because required packages are unavailable, normal execution aborts. A valid later alternative satisfies the mandatory expression. Filter-only exclusions do not trigger a mandatory-package abort, and simulation reports the failure without aborting early.

# QUEUES

A line containing only **---** closes the current normal-repository queue. Packages in one queue are installed in a single APT transaction, and normal queues run sequentially.

Target-release entries are pooled separately by release. Processing order is:

1. Priority normal-repository queue
2. Priority target-release queues
3. Normal queues
4. Remaining target-release queues

The priority list removes matching expressions from their original queues and preserves their complete filters, conditions, versions, and target release. Only the first package token is used for priority matching, so a pattern that matches only a later **||** branch does not prioritize the expression.

# OPERATING MODES

## Simulation

Simulation performs planning but no package installation. It can update APT list state and always exits 1, so its exit status is not a success indicator.

    condinapt -l packages.list -c system.conf -m filters.map -s -v

## Check Only

Check-only evaluates filters and checks package names against the installed package database. It skips **apt-get update** and ignores version and target-release requirements. An alternative is satisfied when any branch is installed. If none is installed, the report and suggested command may contain every failed branch rather than one availability-selected alternative.

    condinapt -l packages.list -c system.conf -m filters.map -C

# EXIT STATUS

**0**
:   Installation completed, help was displayed, or check-only found no missing packages.

**1**
:   Invalid input, missing files, package or APT failure, missing packages in check-only mode, or completion of simulation mode.

# FILES

**condinapt** has no implicit configuration, mapping, or package-list paths. The package list and configuration must be supplied explicitly. The mapping and priority list are optional but are used only when their paths are supplied.

# EXAMPLES

Install a filtered list:

    condinapt -l packages.list -c system.conf -m filters.map

Force an APT list refresh and install priority packages first:

    condinapt -l packages.list -c system.conf -m filters.map \
      -P priority.list -f

# SEE ALSO

**apt**(8), **apt-get**(8), **apt-cache**(8), **condinapt-minios**(7)

# AUTHORS

MiniOS Development Team <https://minios.dev>
