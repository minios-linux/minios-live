# Release Notes v4.1.1

- Removed `/etc/NetworkManager/dispatcher.d/09-timedate` script, because it does not allow user to set time zone by himself and automatically overrides it to the automatically defined one.
- Fixed a bug in minios-configurator that caused incorrect mapping of fields to variables in the config.
- Fixed the way `minios/minios.conf` files on the drive and `/etc/minios/minios/minios.conf` files are synchronized, because of which locale and other settings are not saved when the drive is in read-only mode.
- Updated the help command `man minios-configurator`.
- The firmware module now uses firmware from bookworm-backports.
- Added the rtw89-dkms driver to the repository.
- Fixed a bug that could cause a created user to be deleted in `puzzle` mode.
- Renamed startup.output and statrup.trace logs to minios-startup.output.log and minios-startup.output.log.
- Renamed boot.output and boot.trace logs to minios-boot.output.log and minios-boot.output.log.
- Reworked iso image file system structure, thanks to which there are no more problems with system booting from BIOS when writing to HDD using sector-by-sector copying (dd, Balena Etcher, ...).
- Added copying of ssh public keys to RAM when `toram=trim`.
- Improved user and group file merging in `puzzle` mode.
- MiniOS kernel updated to 6.1.128.
- Added a check to sb2iso that will prevent the iso from being built if the system is loaded with `toram=trim`.
- Fixed a bug in the builder in the `install_packages` function that caused packages from backports to not be installed when using the `-t` option.
- Added deletion of `/var/cache/mandb` at system build to eliminate mandb cache error when installing packages.
- Added `minios-kernelpack` utility to minios-tools to package kernel modules and create initrd.
- Added a hotkey to open the start menu.
