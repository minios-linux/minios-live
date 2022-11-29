# Building and modifying MiniOS (step by step guide)

## First steps

To complete all the steps, you will need a workstation with **Debian 11**/**Ubuntu 20.04** installed, or any distribution with **Docker** installed. First, let's look at building pre-configured MiniOS variants.

```
git clone --depth=1 https://github.com/minios-linux/minios-live.git
```

#### For Debian 11/Ubuntu 20.04

```
cd minios-live
./install -
```

#### For Docker

```
cd minios-live/docker
./01-runme.sh
docker run -it --name mlc --privileged --device-cgroup-rule='b 7:* rmw' -v /dev:/dev -v /home/username/build:/build local/mlc /build/ minios-live/install-
```

where `/home/username/build` \ is the folder\ containing minios-live.

If the build was successful, then in **minios-live/build/iso** you will get a MiniOS Standard image based on Debian 11 and you can continue further.
The main MiniOS build configuration file is **minios-live/linux-live/buildconfig**, for most variables their purpose and values are indicated,
which they can accept. Let's change a few parameters and see what happens.

```
DISTRIBUTION="buster"
DISTRIBUTION_ARCH="i386"
DESKTOP_ENVIRONMENT="xfce"
PACKAGE_VARIANT="minimum"
COMP_TYPE="lz4"
KERNEL_AUFS="true"
INITRD_TYPE="wird"
```

Run build after editing

#### For Debian 11/Ubuntu 20.04

```
./install -
```

#### For Docker

```
docker run -it --name mlc --privileged --device-cgroup-rule='b 7:* rmw' -v /dev:/dev -v /home/username/build:/build local/mlc /build/ minios-live/install-
```

As a result, you should get MiniOS Minimum based on Debian 10, compressed by lz4 with initrd UIRD.

## Modification

### Base system modification

The base system **00-core** is built from scripts located in **minios-live/linux-live/basesystem/00-core**, where you can find package lists for each build option and change them (part of packages installed by the **install** script, since the same package may have different names in different distributions). The **rootcopy-install** folder is also located there, the data from it is automatically copied to the system before installation starts. To copy data to the system after installation, create a **rootcopy-postinstall** folder and place the data in it. At the very end, the **postinstall** script is executed.

### Modifying/creating modules

The scripts from which the modules are assembled are located in **minios-live/linux-live/scripts**, you cannot change the names of modules 00-09. The names of the build scripts, package lists and folders are the same as for the base system, but now the **build** script is added to them. It specifies the operations of building software from source codes, this script is executed after **install**. In this case, the data obtained after the execution of **install** is stored in the **squashfs-root** folder. After assembling the software, the compiled files must be copied to this folder, at the end of the script, you must add these lines

```
if [ $COMP_TYPE = "zstd" ]; then
time mksquashfs /squashfs-root /$MODULE.$BEXT -comp $COMP_TYPE -Xcompression-level 19 -b 1024K -always-use-fragments -noappend >>$OUTPUT 2>&1
else
time mksquashfs /squashfs-root /$MODULE.$BEXT -comp $COMP_TYPE -b 1024K -always-use-fragments -noappend >>$OUTPUT 2>&1
fi
```

. Packages installed by the **build** script are not stored on the system. An example of such a script can be found here **minios-live/linux-live/scripts/04-slax-desktop**. If you need to install the DKMS module so that the system does not have any packages required for assembly (kernel headers and others), create the **is\_dkms\_build** file in the module's scripts folder, then add the \*\*build script to the module after running the script \*\* only kernel modules will be copied. Example: **minios-live/linux-live/scripts/01-kernel**.
To create a simple module where only packages need to be installed, use the **10-galculator** module scripts as an example:

```
cd minios-live/linux-live/scripts
cp -r 10-galculator 10-openshot
```

replace **packages.list** galculator with openshot.

### Building the system with the inclusion of its modules

The building of the system with modules is carried out from folders in **minios-live/linux-live/modules**, where there are links to script folders from which modules are built. In **minios-live/linux-live/modules** there is a script **create\_symlinks.sh** that can be used to create a module structure. For example, we want to build MiniOS with Chromium instead of Firefox, for this we need to edit **create\_symlinks.sh**.

```
#!/bin/bash
if[! -d $1]; then
mkdir -p $1
fi

for file in $1/00-minios\
$1/01-kernel\
$1/02-firmware\
$1/03-xorg\
$1/04-xfce-desktop\
$1/05-xfce-apps\
$1/10-chromium; do
if [ -L $file ]; then
rm $file
fi
ln -s ../../scripts/$(basename $file) $file
done
```

Then run the script: `create_symlinks.sh xfce-chromium` change **DESKTOP\_ENVIRONMENT** in **buildconfig** to xfce-chromium. Note to keep "xfce" if you are using XFCE in the system variant name.

### Building modules for the built system

Let's say you've just built a system and you need to make changes to a module. In the folder **minios-live/build/bullseye-standard-amd64/image/minios** (for other options, the folder may be called differently), delete the module and all modules that are alphabetically located after it, then run the build:
`./install build_modules -`
For the version of Puzzle for modules with serial numbers 10 and higher, it is not necessary to remove the modules located alphabetically after.