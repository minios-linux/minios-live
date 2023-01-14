# Construyendo y modificando MiniOS (guía paso a paso)

## Primeros pasos

Para completar todos los pasos, necesitará una estación de trabajo con **Debian 11**/**Ubuntu 20.04** instalado, o cualquier distribución con **Docker** instalado. Primero, echemos un vistazo a la creación de variantes de MiniOS preconfiguradas.

```
git clone --depth=1 https://github.com/minios-linux/minios-live.git
```

#### Para Debian 11/Ubuntu 20.04

```
cd minios-live
./install -
```

#### Para Docker

```
cd minios-live/docker
./01-runme.sh
docker run -it --name mlc --privileged --device-cgroup-rule='b 7:* rmw' -v /dev:/dev -v /home/username/build:/build local/mlc /build/ minios-live/install-
```

donde `/home/username/build` \ es la carpeta\ que contiene minios\-live\.

Si la compilación fue exitosa, en **minios-live/build/iso** obtendrá una imagen estándar de MiniOS basada en Debian 11 y podrá continuar.
El archivo de configuración de compilación principal de MiniOS es **minios-live/linux-live/buildconfig**, para la mayoría de las variables se indica su propósito y valores, que pueden aceptar. Cambiemos algunos parámetros y veamos qué sucede.

```
DISTRIBUTION="buster"
DISTRIBUTION_ARCH="i386"
DESKTOP_ENVIRONMENT="xfce"
PACKAGE_VARIANT="minimum"
COMP_TYPE="lz4"
KERNEL_AUFS="true"
INITRD_TYPE="wird"
```

Ejecuta la compilación despues de editar

#### Para Debian 11/Ubuntu 20.04

```
./install -
```

#### Para Docker

```
docker run -it --name mlc --privileged --device-cgroup-rule='b 7:* rmw' -v /dev:/dev -v /home/username/build:/build local/mlc /build/ minios-live/install-
```

Como resultado, debe obtener MiniOS basado en Debian 10, comprimido  por lz4 con initrd UIRD.

## Modificación

### Modificación del sistema base

El sistema base **00-core** se crea a partir de el script ubicado en **minios-live/linux-live/basesystem/00-core**, donde pues encontrar listas de paquetes para cada opción de compilación y cambiarlas (parte de los paquetes instalados por el script **instalación**, ya que el mismo paquete puede tener diferentes nombres en diferentes distribuciones). La carpeta **rootcopy-install** también se encuentran allí, los datos de la misma se copian automáticamente en el sistema antes de que comience la instalación. Para copiar datos al sistema después de la instalación, cree una carpeta **rootcopy-postinstall** y coloque los datos en ella. Al final, se ejecuta el script de **postinstall**.

### Modificando/creando modulos

Los scripts a partir de los cuales se ensamblan los módulos se encuentran en **minios-live/linux-live/scripts**, no puede cambiar los nombres de los módulos 00-09. Los nombres de los scripts de compilación, las listas de paquetes y las carpetas son los mismos para le sistema base, pero ahora se les agrega el script de **compilación**. Especifica las operaciones de creación de software a partir del código fuente, este script se ejecuta después de la **instalación**. En este caso, los datos obtenidos después de la ejecución de la **instalación** se almacenan en la carpeta **squashfs-root**. Despues de ensamblar el software, los archivos compilados deben copiarse en esta carpeta, al final del script, debe agregar estas líneas.

```
if [ $COMP_TYPE = "zstd" ]; then
time mksquashfs /squashfs-root /$MODULE.$BEXT -comp $COMP_TYPE -Xcompression-level 19 -b 1024K -always-use-fragments -noappend >>$OUTPUT 2>&1
else
time mksquashfs /squashfs-root /$MODULE.$BEXT -comp $COMP_TYPE -b 1024K -always-use-fragments -noappend >>$OUTPUT 2>&1
fi
```

Los paquetes instalados por el script de **compilación** no se almacenan en el sistema. Puede encontrar un ejemplo de dicho script aquí **minios-live/linux-live/scripts/04-slax-desktop**. Si necesita instalar el módulo DKMS para que el sistema no tenga ningún paquetes (kernel headers y otros), cree el archivo **is\_dkms\_build** en la carpeta de scripts del módulo, luego agregue el **script de compilación al módulo después de ejecutar el script ** solo se copiarán los módulos del kernel. Ejemplo: **minios-live/linux-live/scripts/01-kernel**.
Para crear un módulo simple en el que solo se deban instalar paquetes, use los scripts del módulo **10-galculator** como ejemplo:

```
cd minios-live/linux-live/scripts
cp -r 10-galculator 10-openshot
```

reemplazar **packages.list** galculator con openshot.

### Construyendo el sistema con la inclusión de sus módulos

La construcción del sistema con módulos se realiza desde la carpeta **minios-live/linux-live/modules**, donde hay enlaces a carpetas de scripts a partir de las cuales se construyen los módulos. En **minios-live/linux-live/modules** hay un script **create\_symlinks.sh** que se puede usar para crear una estructura de módulo. Por ejemplo, queremos construir MiniOS con Chromium en lugar de Firefox, para esto necesitamos editar **create\_symlinks.sh**.

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

Luego ejecute el script `create_symlinks.sh xfce-chromium` cambie **DESKTOP\_ENVIRONMENT** en **buildconfig** para xfce-chromium. Tenga en cuenta que debe mantener "xfce" si usa XFCE en el nombre de la variable del sistema.

### Construcción de módulos para el sistema construido

Digamos que acaba de crear un sistema y necesita realizar cambios en un modulo. En la carpeta **minios-live/build/bullseye-standard-amd64/image/minios** (para otras opciones, la carpeta puede tener un nombre diferente), elimine el módulo y todos los módulos que se encuentran alfabéticamente después de él, luego ejecute la compilación:
`./install build_modules -`
Para la versión de Frugal para módulos con números de serie 10 y superiores, no es necesario eliminar los módulos ubicados alfabéticamente despues.