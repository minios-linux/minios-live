# MiniOS

Эти скрипты собирают загружаемый ISO образ MiniOS.

Для установки используйте **install** - скрипт для управляемой установки, **autoinstall** - скрипт для автоматической установки.

**Ни в коем случае не запускайте скрипты из linux-live! Они сломают вам систему.**

**Поддерживаемые команды:** `setup_host build_bootstrap build_chroot build_live build_modules build_iso`

*setup_host* - установка пакетов, необходимых для сборки, на хост

*build_bootstrap* - установка минимальной системы с помощью debootstrap

*build_chroot* - установка остальных компонентов, необходимых для запуска системы

*build_live* - сборка initramfs и образа squashfs

*build_modules_chroot* - сборка модулей

*build_iso* - сборка итогового образа ISO

**Синтаксис:** `./install [start_cmd] [-] [end_cmd]`
- запуск от start_cmd до end_cmd
- если start_cmd опущен, выполняются все команды, начиная с первой
- если end_cmd опущен, выполняются все команды до последней
- введите одну команду, чтобы запустить определенную команду
- введите '-' как единственный аргумент для запуска всех команд

        Примеры:./install build_bootstrap - build_chroot
                ./install - build_chroot
                ./install build_bootstrap -
                ./install build_iso
                ./install -

Для сборки с помошью докера создайте в домашней папке папку build, поместите туда minios-slax, запустите 01-runme.sh из папки docker. Данное действие установит необходимые программы и создаст образ. Для запуска сборки отредактируйте под себя и запустите 02-build.sh. Пример содержимого файла:

`docker run --rm -it --name mlc --privileged -v /home/user/build:/build local/mlc /build/minios-slax/install -`

# MiniOS

These scripts build a bootable MiniOS ISO image.

For installation use **install** - script for guided installation, **autoinstall** - script for automatic installation.

**Never run scripts from linux-live! They will break your system.**

**Supported commands:** `setup_host build_bootstrap build_chroot build_live build_modules build_iso`

*setup_host* - installing packages required for building on the host

*build_bootstrap* - install a minimal system using debootstrap

*build_chroot* - installation of the rest of the components required to start the system

*build_live* - build initramfs and squashfs image

*build_modules_chroot* - building modules

*build_iso* - build the final ISO image

**Syntax:** `./install [start_cmd] [-] [end_cmd]`
- launch from start_cmd to end_cmd
- if start_cmd is omitted, all commands are executed starting from the first
- if end_cmd is omitted, all commands up to the last are executed
- enter one command to run a specific command
- enter '-' as the only argument to run all commands

        Examples: ./ install build_bootstrap - build_chroot
                ./install - build_chroot
                ./install build_bootstrap -
                ./install build_iso
                ./install -

To build with docker, create a build folder in your home folder, put minios-slax there, run 01-runme.sh from the docker folder. This action will install the required programs and create an image. To start the build, edit for yourself and run 02-build.sh. Sample file content:

`docker run --rm -it --name mlc --privileged -v /home/user/build:/build local/mlc /build/minios-slax/install -`
