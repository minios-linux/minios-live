# Release Notes v3.1

- The LANG variable in all scripts has been replaced by LNG to avoid conflict with the system variable.
- RT, Cloud kernels are no longer present in the distribution.
- Kernels 5.10 and 6.1 of the amd64, 686, 686-pae architectures are updated to current versions.
- The splash screen on syslinux startup is now at 1024x768 instead of 640x480, and the menus have been rearranged.
- Added parameter system_type/SYSTEM_TYPE to the kernel parameters and the configuration file, which allows to switch the modules into classic mode (more details in the linux-live/buildconfig comments).
- Added console script minios-resolution, which allows to add a non-standard resolution to the screen settings (it does not work perfectly and not always, additional testing is needed).
- Optimized the code of some scripts.
- A new version of dynfilefs has been added, it is no longer necessary to specify the size of the change file, this option has been removed.
