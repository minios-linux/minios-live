# MiniOS Slax

Этот скрипт собирает загружаемый ISO образ MiniOS Slax.

**Поддерживаемые команды:** `setup_host build_bootstrap build_chroot build_live build_modules_chroot build_modules_live build_iso`

*setup_host* - установка пакетов, необходимых для сборки, на хост

*build_bootstrap* - установка минимальной системы с помощью debootstrap

*build_chroot* - установка остальных компонентов, необходимых для запуска системы

*build_live* - сборка initramfs и образа squashfs

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

**!!!Сборка с помощью докера пока не работает!!!**
Для сборки с помошью докера создайте в домашней папке папку build, поместите туда minios-slax и используйте команду для автоматической установки:

`sudo docker run -it --rm --cap-add SYS_ADMIN -v /home/user/build:/build ubuntu:trusty /build/minios-slax/autoinstall -`

либо для установки в ручном режиме:

`sudo docker run -it --rm --cap-add SYS_ADMIN -v /home/user/build:/build ubuntu:trusty /build/minios-slax/install -`

Для использования сборки в специально подготовленном контейнере используйте следующие примеры команд:

`sudo docker run -it --rm --cap-add SYS_ADMIN -v /home/user/build:/build crims0n/minios-slax-container` - пример сборки с выводом информации в консоль

`sudo docker run -d --name=minios-slax-build --cap-add SYS_ADMIN -v /home/user/build:/build crims0n/minios-slax-container` - пример сборки в фоне без удаления контейнера по окончании сборки
