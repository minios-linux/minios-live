## MiniOS configuration file

MiniOS se diferencia de la mayoría de las distribuciones flash clásicas en que algunos parámetros se pueden configurar antes del arranque en un archivo de configuración bastante simple `minios/minios.conf`, lo que minimiza la cantidad de trabajo requerido al crear sus propios módulos para crear sistemas embebidos. Opcionalmente, algunos de los parámetros se pueden configurar en los parámetros de arranque. Las opciones de arranque tienen prioridad sobre el archivo de configuración. Algunos parámetros de este archivo son de servicio y es mejor no cambiarlos. A continuación se muestra un ejemplo de un archivo de configuración estándar:

```
USER_NAME="live"
USER_PASSWORD="evil"
ROOT_PASSWORD="toor"
HOST_NAME="minios"
DEFAULT_TARGET="graphical"
ENABLE_SERVICES="ssh"
DISABLE_SERVICES=""
SSH_KEY="authorized_keys"
CLOUD="false"
SCRIPTS="true"
HIDE_CREDENTIALS="false"
AUTOLOGIN="true"
CORE_BUNDLE_PREFIX="00-core"
BEXT="sb"
```

Algunas de estas opciones solo se pueden configurar una vez, antes de la primera carga, si está utilizando en modo persistente. En el modo persistente, solo se pueden cambiar siempre los siguientes parámetros:

```
USER_PASSWORD
ROOT_PASSWORD
ENABLE_SERVICES
DISABLE_SERVICES
SSH_KEY
HIDE_CREDENTIALS
AUTOLOGIN
```

## Descripción de los parámetros

| Parámetro | Significado | Ejemplo | Con que initrd trabaja |
| --------- | ------- | ------- | ----------------------- |
| USER\_NAME | El nombre del usuario cuyo perfil se creará en el primero arranque. Si especifica el nombre de usuario <strong>root</strong>, entonces no se creará ningún perfil de usuario, el parámetro **USER\_PASSWORD** se ignorará, y el inicio de sesión se realizará utilizando el perfil  <strong>root</strong>. | USER\_NAME=live<br>USER\_NAME=user<br>USER\_NAME=root | <ul><li>MiniOS Live Kit</li></ul><ul><li>Slax Live Kit</li></ul><ul><li>UIRD</li></ul> |
| USER\_PASSWORD | La contraseña de un usuario principalmente en texto claro. La contraseña no debe incluir `'` , `\` , y otros caracteres que bash pueda malinterpretar. | USER\_PASSWORD=evil<br>USER\_PASSWORD=PxKYJnLK8cv0E3Hd | <ul><li>MiniOS Live Kit</li></ul><ul><li>Slax Live Kit</li></ul><ul><li>UIRD</li></ul> |
| ROOT\_PASSWORD | Contraseña del usuario privilegiado **root** en texto claro. La contraseña no debe incluir `'` , `\` , y otros caracteres que bash pueda malinterpretar. | ROOT\_PASSWORD=toor<br>ROOT\_PASSWORD=9gVIlgGsZtpKPsE8 | <ul><li>MiniOS Live Kit</li></ul><ul><li>Slax Live Kit</li></ul><ul><li>UIRD</li></ul> |
| HOST\_NAME | El nombre del nodo asociado con el sistema. | HOST\_NAME=minios | <ul><li>MiniOS Live Kit</li></ul><ul><li>Slax Live Kit</li></ul><ul><li>UIRD</li></ul> |
| DEFAULT\_TARGET | El proposito de systemd. Puede leer más sobre los objetivos de systemd [aquí](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_basic_system_settings/working-with-systemd-targets_configuring-basic-system-settings). | DEFAULT\_TARGET=graphical<br>DEFAULT\_TARGET=multi-user | <ul><li>MiniOS Live Kit</li></ul> |
| ENABLE\_SERVICES | Habilite los servicios en el arranque. | ENABLE\_SERVICES=ssh<br>ENABLE\_SERVICES=ssh,firewalld | <ul><li>MiniOS Live Kit</li></ul> |
| DISABLE\_SERVICES | Deshabilita los servicios en el arranque. | DISABLE\_SERVICES=docker<br>DISABLE\_SERVICES=docker,firewalld,ssh | <ul><li>MiniOS Live Kit</li></ul> |
| SSH\_KEY | El nombre del archivo de la clave pública SSH, que debe estar ubicado en la carpeta del sistema en los medios (junto con los módulos .sb principales). De manera predeterminada, el sistema busca un archivo llamado <strong>authorized\_keys</strong>.<br>Este archivo se copiará en `~/.ssh/authorized_keys` del usuario principal y del usuario root cuando se inicie el sistema, y se puede usar para autorizar con el uso de claves SSH. | SSH\_KEY=authorized\_keys<br>SSH\_KEY=my\_public\_key.pub | <ul><li>MiniOS Live Kit</li></ul><ul><li>Slax Live Kit</li></ul><ul><li>UIRD</li></ul> |
| CLOUD | El parámetro de servicio, necesario para su uso con cloud-init, no se aplica a las versiones publcias de MiniOS. | CLOUD=false | <ul><li>MiniOS Live Kit</li></ul> |
| SCRIPTS | Ejecutar scripts de shell desde la carpeta minios/scripts, habilitado de forma predeterminada. Los scripts se ejecutan automáticamente en tty2 después de llegar a multi-user.target (init 3). | SCRIPTS=true | <ul><li>MiniOS Live Kit</li></ul><ul><li>Slax Live Kit</li></ul><ul><li>UIRD</li></ul> |
| HIDE\_CREDENTIALS | Oculte las credenciales que se muestran como información sobre herramientas en tty. Deshabilitado por defecto. | HIDE\_CREDENTIALS=false | <ul><li>MiniOS Live Kit</li></ul><ul><li>Slax Live Kit</li></ul><ul><li>UIRD</li></ul> |
| AUTOLOGIN | Habiltiar/Deshabilitar el inicio de sesión automático. Habilitado por defecto. | AUTOLOGIN=true | <ul><li>MiniOS Live Kit</li></ul><ul><li>Slax Live Kit</li></ul><ul><li>UIRD</li></ul> |
| CORE\_BUNDLE\_PREFIX | Un parámetro de servicio que le dice a las utilidades en el sistema el nombre del módulo con el sistema base. | CORE\_BUNDLE\_PREFIX=00-core | <ul><li>MiniOS Live Kit</li></ul><ul><li>Slax Live Kit</li></ul><ul><li>UIRD</li></ul> |
| BEXT | Un parámetro de servicio que indica a las utilidades del sistema la extensión en el nombre de archivo del módulo. | BEXT=sb | <ul><li>MiniOS Live Kit</li></ul><ul><li>Slax Live Kit</li></ul><ul><li>UIRD</li></ul> |

***

## Importante!

* El servidor SSH está habilitado de forma predeterminada para compatibilidad con initrd de terceros, para dehabilitar esto, no solo debe eliminarlo de `ENABLE_SERVICES`, sino tambien debe agregarlo a `DISABLE_SERVICES`.
* **Cuando inicia por primera vez** en modo persistencia, o si está utilizando el modo de inicio limpio o de RAM, puede cambiar opcionalmente los parámetros `HOST_NAME` y `DEFAULT_TARGET`.
* Los parámetros `CLOUD`, `CORE_BUNDLE_PREFIX` y `BEXT` no se pueden cambiar, son de servicio y se utilizan en versiones no públicas no estándar de MiniOS (virtualización en la nube, diseño de módulos no estándar, etc).
* Cuando estamos usando otro initrd que no sea MiniOS Live Kit, algunas de las opciones no estarán disponibles, preste atención a la columna de la derecha.

¿Para qué más puede ser útil el archivo `minios.conf`? Puede usarlo para establecer sus propios parámetros en sus scripts al crear módulos. En el primer arranque, se copia en la carpeta /etc/minios, luego el archivo `/etc/minios/minios.conf` se supervisa automáticamente y, cuando se realizan cambiuos, sobreescribe el archivo de configuración en la unidad flash, si se puede escribir. Por lo tanto, puede poner sus variable en el `/etc/minios/minios.conf` en sus scripts indeependientemente del tipo de initrd utilizado.