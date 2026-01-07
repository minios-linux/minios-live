# Release Notes v3.3.4

- Restored the ability to build the distribution on the 3.3.x branch, due to a change in the repository structure it was not possible.
- Updated MiniOS Installer to a version similar to MiniOS 4.0 under development, added support for MMC devices (mmcblk) and exFAT support.
- Updated some scripts involved in system booting to fix the problem with package updates in Puzzle.
- Updated kernel to 6.1.90.
- Icon theme elementary-xfce-minios replaced by elementary-minios and updated to 0.19.
- All modules are zstd compressed in this release.
- Fixed GUI loading in Flux and Minimum.
- The gtkdialog utility from Slax has been renamed gtkask to avoid conflicts with the original GTKDialog utility.
- Improved detection of the required kernel for installation.
