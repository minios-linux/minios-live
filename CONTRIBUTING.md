# Contributing to MiniOS Live

Thank you for your interest in contributing to MiniOS Live! This document provides guidelines and best practices for contributing to the project.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Development Setup](#development-setup)
3. [Code Quality Standards](#code-quality-standards)
4. [Testing](#testing)
5. [Submitting Changes](#submitting-changes)
6. [Code Review Process](#code-review-process)

## Getting Started

MiniOS Live is a collection of bash scripts for building bootable MiniOS ISO images. Before contributing, please:

1. Read the [README.md](README.md) to understand the project
2. Check the [official Wiki](https://github.com/minios-linux/minios-live/wiki) for detailed documentation
3. Review the [CHANGES.md](CHANGES.md) to understand recent developments
4. Look at existing [issues](https://github.com/minios-linux/minios-live/issues) to find areas where you can help

## Development Setup

### Prerequisites

- Bash 4.4 or later
- Standard GNU utilities (grep, sed, awk, etc.)
- ShellCheck for code quality checks
- Debian-based system for building (recommended)

### Clone the Repository

```bash
git clone https://github.com/minios-linux/minios-live.git
cd minios-live
```

### Install Dependencies

On Debian/Ubuntu:

```bash
sudo apt-get update
sudo apt-get install debootstrap xorriso binutils squashfs-tools grub-common \
  mtools xz-utils liblz4-tool zstd curl rsync gpg gettext cpio shellcheck
```

## Code Quality Standards

### Shell Script Guidelines

1. **Follow bash best practices**:
   - Use `set -e`, `set -u`, and `set -o pipefail` at the start of scripts
   - Quote all variable expansions: `"$variable"` instead of `$variable`
   - Use `[[` for conditionals instead of `[`
   - Avoid `eval` unless absolutely necessary

2. **Use ShellCheck**:
   ```bash
   shellcheck minios-live minios-cmd
   shellcheck linux-live/**/*.sh
   ```

3. **Code style**:
   - Use 4 spaces for indentation (no tabs)
   - Keep lines under 120 characters when possible
   - Use descriptive variable names (UPPERCASE for exported/global, lowercase for local)
   - Add comments for complex logic

4. **Function documentation**:
   ```bash
   # Function: my_function
   # Description: Brief description of what the function does
   # Arguments:
   #   $1 - First argument description
   #   $2 - Second argument description
   # Returns:
   #   0 on success, non-zero on failure
   my_function() {
       local arg1="$1"
       local arg2="$2"
       # Function implementation
   }
   ```

### Commit Messages

Follow the conventional commit format:

```
type(scope): subject

body (optional)

footer (optional)
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(build): add support for Ubuntu Noble
fix(minioslib): correct regex pattern in package filtering
docs(readme): update installation instructions
```

## Testing

### Running Tests

1. **ShellCheck validation**:
   ```bash
   shellcheck minios-live minios-cmd
   ```

2. **CondinAPT tests**:
   ```bash
   cd linux-live
   ./test_condinapt.sh ./condinapt
   ```

3. **Syntax check**:
   ```bash
   bash -n minios-live
   bash -n minios-cmd
   ```

### Adding New Tests

When adding new functionality:

1. Add appropriate test cases in `linux-live/test_condinapt.sh` if your changes affect package management
2. Test your changes with different configurations in `linux-live/build.conf`
3. Verify backward compatibility with existing builds

## Submitting Changes

### Before Submitting

1. **Test your changes**: Ensure all tests pass
2. **Run ShellCheck**: Fix any warnings or errors
3. **Update documentation**: Update relevant documentation files
4. **Check commit messages**: Ensure they follow the conventional format

### Pull Request Process

1. **Fork the repository** and create a feature branch:
   ```bash
   git checkout -b feature/my-new-feature
   ```

2. **Make your changes** following the code quality standards

3. **Commit your changes** with clear, descriptive messages:
   ```bash
   git commit -m "feat(scope): add new feature description"
   ```

4. **Push to your fork**:
   ```bash
   git push origin feature/my-new-feature
   ```

5. **Create a Pull Request** from your fork to the main repository

### Pull Request Guidelines

- Provide a clear description of the changes
- Reference any related issues
- Include screenshots for UI changes
- Ensure all CI checks pass
- Be responsive to feedback during code review

## Code Review Process

1. **Automated checks**: GitHub Actions will run ShellCheck and tests
2. **Maintainer review**: A project maintainer will review your code
3. **Feedback**: Address any requested changes
4. **Approval**: Once approved, your changes will be merged

### Review Criteria

- Code follows project standards
- Changes are well-documented
- Tests pass successfully
- No regressions introduced
- Security best practices followed

## Additional Resources

- [Official Website](https://minios.dev)
- [Wiki Documentation](https://github.com/minios-linux/minios-live/wiki)
- [Issue Tracker](https://github.com/minios-linux/minios-live/issues)
- [Discussion Forum](https://github.com/minios-linux/minios-live/discussions)

## Questions?

If you have questions about contributing, feel free to:
- Open a [discussion](https://github.com/minios-linux/minios-live/discussions)
- Ask in an existing issue
- Contact the maintainers

Thank you for contributing to MiniOS Live! 🎉
