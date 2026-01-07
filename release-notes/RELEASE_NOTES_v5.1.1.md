# Release Notes v5.1.1

This release focuses on bug fixes, improvements in Secure Boot support, and enhancements to the build system and configuration.

## 1. Critical Bug Fixes
- Fixed `live-config` component execution error that prevented proper system initialization
- Corrected session manager default size calculation and filesystem operations
- Fixed installer integration with configurator and boot menu language detection
- Resolved Ventoy compatibility issues across multiple tools

## 2. Build System and Code Quality Optimization
- Refined Secure Boot support with improved lockdown mode detection in `minioslib` and GRUB configuration
- Enhanced Dracut integration as a primary initramfs builder with automatic detection
- Improved unmounting process with lazy unmount fallback and resource release delay
- Refactored package list for XFCE desktop, removing unnecessary dependencies
- Updated `ntfs3-dkms` and `realtek-rtl8723cs-dkms` dependencies
- Added locale cleanup for Ubuntu and updated pulseaudio condition

## 3. MiniOS Tools (minios-tools package)
- Enhanced `lightdm` configuration to dynamically detect and set autologin session
- Updated `lightdm-gtk-greeter` configuration to set font size, add indicators, and update default user image format
- Added locale, timezone, and keyboard parameters to kernel command line in GRUB config
- Improved Ventoy compatibility across all tools with new cleanup function

## 4. System Components
- Enhanced `live-config` components to support default Debian Live paths alongside MiniOS paths
- Added conditional font loading in GRUB based on lockdown status
- Fixed execution errors in configuration scripts

## 5. Submodule Updates
- Updated flux.minios.dev with new translations and improved language handling
- Added app.js with download functionality
- Standardized all translation files with new structure
- Added missing translation keys across all languages
