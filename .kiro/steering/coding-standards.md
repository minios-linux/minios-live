# Coding Standards

## Shell Script Guidelines

### Script Header
```bash
#!/bin/bash

set -e          # exit on error
set -o pipefail # exit on pipeline error
set -u          # treat unset variable as error

SET_E=""
SET_U=""
```

### Sourcing Libraries
```bash
. /minioslib || exit 1
. /minios_build.conf || exit 1
```

### Variable Naming
- Use UPPERCASE for configuration variables
- Use lowercase for local variables
- Prefix with module context when appropriate

### Error Handling
```bash
# Use library functions
error "Error message"
warning "Warning message"
information "Info message"

# Toggle shell options safely
toggle_shell_options e  # Disable -e temporarily
# risky operation
toggle_shell_options e  # Re-enable -e
```

### Long Operations
```bash
# Use spinner for user feedback
run_with_spinner "Installing packages" apt-get install -y package

# Or for custom commands
run_with_spinner "Building module" ./build-script
```

### Configuration Reading
```bash
# Read specific variables
read_config "$CONFIG_FILE" VAR1 VAR2 VAR3

# Read single value
VALUE=$(read_config_value "$CONFIG_FILE" "VARIABLE")

# Update configuration
update_config "$CONFIG_FILE" VAR1 VAR2
```

### Package Checks
```bash
# Check if installed
if pkg_is_installed "package-name"; then
    # package is installed
fi

# Version comparison
if pkg_test_version "package" "ge" "1.0"; then
    # version >= 1.0
fi
```

## File Organization

### Module Scripts
- Keep `install` scripts focused and readable
- Use `packages.list` for package management
- Separate build logic into `build` script
- Use `postinstall` for final configuration

### Configuration Files
- Document all variables with comments
- Group related settings with section headers
- Use sensible defaults

## Testing

### Simulation Mode
```bash
# Test package installation
condinapt -l packages.list -c config -s

# Check installed packages
condinapt -l packages.list -c config -C
```

### Verbose Builds
```bash
# Set verbosity in build.conf
VERBOSITY_LEVEL=2

# Or via environment
VERBOSITY_LEVEL=2 ./minios-live -
```

## Documentation

- Add comments for complex logic
- Document skip conditions
- Include README.md for custom modules
- Update man pages for CLI changes
