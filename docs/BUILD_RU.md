# Сборка и модификация MiniOS (пошаговое руководство)

## Первые шаги

Для выполнения всех действий вам понадобится рабочая станция с установленным **Debian 11**/**Ubuntu 20.04**, либо любой дистрибутив с установленным **Docker**. Сначала рассмотрим сборку преднастроенных вариантов MiniOS.

```
git clone --depth=1 https://github.com/minios-linux/minios-live.git
```

##### Для Debian 11/Ubuntu 20.04

```
cd minios-live
./install -
```

##### Для Docker

```
cd minios-live/docker
./01-runme.sh
docker run -it --name mlc --privileged --device-cgroup-rule='b 7:* rmw' -v /dev:/dev -v /home/username/build:/build local/mlc /build/minios-live/install -
```

где `/home/username/build` \- папка\, содержащая minios\-live\.

Если сборка прошла успешно, то в **minios-live/build/iso** вы получите образ MiniOS Standard на базе Debian 11 и можно продолжать далее.
Основной файл конфигурации сборки MiniOS - **minios-live/linux-live/buildconfig**, для большинства переменных указано их назначение и значения,
которые они могут принимать. Давайте изменим несколько параметров и посмотрим, что получится.

```
DISTRIBUTION="buster"
DISTRIBUTION_ARCH="i386"
DESKTOP_ENVIRONMENT="xfce"
PACKAGE_VARIANT="minimum"
COMP_TYPE="lz4"
KERNEL_AUFS="true"
INITRD_TYPE="uird"
```

После редактирования запустите сборку

##### Для Debian 11/Ubuntu 20.04

```
./install -
```

##### Для Docker

```
docker run -it --name mlc --privileged --device-cgroup-rule='b 7:* rmw' -v /dev:/dev -v /home/username/build:/build local/mlc /build/minios-live/install -
```

На выходе вы должны получить MiniOS Minimum на базе Debian 10, сжатый lz4 с initrd UIRD.

## Модификация

### Модификация базовой системы

Сборка базовой системы **00-core** производится из скриптов, расположеных в **minios-live/linux-live/basesystem/00-core**, там вы можете найти списки пакетов для каждого варианта сборки и изменить их (часть пакетов устанавливается скриптом **install**, так как в разных дистрибутивах один и тот же пакет может иметь разные названия).Там же расположена папка **rootcopy-install**, данные из неё автоматически копируются в систему перед началом установки. Для копирования данных в систему после установки создайте папку **rootcopy-postinstall** и разместите данные в ней. В самом конце выполняется скрипт **postinstall**.

### Модификация/создание модулей

Скрипты, из которых собираются модули, располагаются в **minios-live/linux-live/scripts**, менять наименования модулей 00-09 нельзя. Наименования скриптов сборки, списков пакетов и папок те же, что и для базовой системы, но теперь к ним добавляется скрипт **build**. В нём указываются операции сборки ПО из исходных кодов, данный скрипт выполняется после **install**. При этом, данные, полученные после выполнения **install**, сохраняются в папке **squashfs-root**. После сборки ПО скомпилированные файлы необходимо скопировать в эту папку, в конце скрипта необходимо добавить эти строки

```
if [ $COMP_TYPE = "zstd" ]; then
    time mksquashfs /squashfs-root /$MODULE.$BEXT -comp $COMP_TYPE -Xcompression-level 19 -b 1024K -always-use-fragments -noappend
else
    time mksquashfs /squashfs-root /$MODULE.$BEXT -comp $COMP_TYPE -b 1024K -always-use-fragments -noappend
fi
```

. Пакеты, установленые скриптом **build** не сохраняются в системе. Пример такого скрипта можно посмотреть здесь **minios-live/linux-live/scripts/04-flux-desktop**. Если вам необходимо установить модуль DKMS так, чтобы в системе не осталось пакетов, необходимых для сборки (заголовки ядра и прочие), создайте в папке скриптов модуля файл **is\_dkms\_build**, тогда в модуль после работы скрипта **build** будут скопированы только модули ядра. Пример: **minios-live/linux-live/scripts/01-kernel**.
Для создания простого модуля, где необходима только установка пакетов, используйте в качестве примера скрипты модуля **10-galculator**:

```
cd minios-live/linux-live/scripts
cp -r 10-galculator 10-openshot
```

замените в **packages.list** galculator на openshot.

### Сборка системы с включением своих модулей

Сборка системы с модулями осуществляется из папок в **minios-live/linux-live/modules**, где расположены ссылки на папки скриптов, из которых собираются модули. В **minios-live/linux-live/modules** есть скрипт **create\_symlinks.sh**, с помощью которого можно создать структуру модулей. Например, мы хотим собрать MiniOS с Chromium вместо Firefox, для этого необходимо отредактировать **create\_symlinks.sh**.

```
#!/bin/bash
if [ ! -d $1 ]; then
   mkdir -p $1
fi

for file in $1/00-minios \
   $1/01-kernel \
   $1/02-firmware \
   $1/03-xorg \
   $1/04-xfce-desktop \
   $1/05-xfce-apps \
   $1/10-chromium; do
   if [ -L $file ]; then
      rm $file
   fi
   ln -s ../../scripts/$(basename $file) $file
done
```

Затем запустите скрипт: `create_symlinks.sh xfce-chromium` измените **DESKTOP\_ENVIRONMENT** в **buildconfig** на xfce-chromium. Обратите внимание, сохранять "xfce", если вы используете XFCE, в наименовании варианта системы и в начале переменой **DESKTOP\_ENVIRONMENT** обязательно.

### Сборка модулей для собранной системы

Допустим, вы только что собрали собрали систему и вам необходимо внести изменения модуль. В папке **minios-live/build/bullseye-standard-amd64/image/minios** (для других вариантов папка может называться иначе) удалите модуль и все модули, которые по алфавиту располагаются после него, затем запустите сборку:
`./install build_modules -`
Для версии Puzzle для модулей с порядковыми номерами 10 и выше удалять модули, располагающиеся по алфавиту после, не надо.