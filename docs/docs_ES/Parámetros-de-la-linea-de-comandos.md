# Parámetros de la linea de comandos

Los parámetros de arranque (también conocidos como cheatcodes) se utilizan para afectar el proceso de arranque de MiniOS. Algunos de ellos son comunes pra todos los Linux, otros son especificos solo para MiniOS. Puede usarlos para deshabilitar el tipo deseado de detección de hardware, para iniciar MiniOS desde le disco duro, etc. Para usar cheatcodes con syslinux, presione la tecla `Esc` para activar el menú de inicio durante el inicio de MiniOS como de costumbre, y cuando vea el menú de inicio, presione `Tab`, edite los parámetros de inicio, luego presione Enter. Para grub, presione `E` para editar, luego `F10` para inciar. Aparecerá una línea de comando en la parte inferior de la pantalla, que puede editar o agregar nuevos parámetros de arranque al final. Algunas opciones de grub no se pueden cambiar de manera interactiva. Para cambiarlos, edite `boot/grub/grub.cfg`.

| Cheatcode | Meaning | Example |
| --------- | ------- | ------- |
| from= | Cargue datos de MiniOS desde el directorio especifico o incluso desde un archivo ISO. | from=/minios/ |
|  |  | from=/Descargas/minios.iso |
|  |  | from=http://dominio.com/minios.iso |
| noload= | Deshabilite la carga de modulos .sb particulares especificados como expresión regular. | noload=04-xfce-apps |
|  |  | noload=xfce-apps,browser |
|  |  | noload=04,05 |
| nosound | Silenciar el sonido al inciar. | nosound |
| toram | Activa la función de Copiar a RAM. | minios.flags=toram |
| perch | Active la función de cambios persistentes. | minios.flags=toram,perch |
| text | Deshabilite el inicio de X y permanezca solo en consola de modo de texto. | text |
| debug | Habilitar la depuración de inicio de MiniOS. | debug |
| root\_password= | Contraseña ROOT. | root\_password=toor |
| user\_name= | Nombre de usuario, Si especifica el nombre de usuario <strong>root</strong>, no se creara el perfil de usuario y se ignorará el parámetro **user\_password**. | user\_name=live |
| user\_password= | Contraseña de usuario. | user\_password=evil |
| host\_name= | Nombre de host del sistema. | host\_name=minios |
| default\_target= | Destino de systemd. Puede leer más sobre los objetivos de ssytemd [aquí](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_basic_system_settings/working-with-systemd-targets_configuring-basic-system-settings). | default\_target=graphical |
|  |  | default\_target=multi-user |
|  |  | default\_target=emergency |
| enable\_services= | Habilite los servicios en el arranque. | enable\_services=ssh,firewalld |
| disable\_services= | Deshabilite los servicios en el arranque. | disable\_services=docker |
| ssh\_key= | El nombre del archivo de clave ssh, que debe estar ubicado en la carpeta del sistema en los medio (junto con los módulos princiales .sb). De manera predeterminada, el sistema buscara un archivo llamado <strong>authorized\_keys</strong>. | ssh\_key=my\_public\_keys |
| scripts= | Los scripts se ejecutan cuando se alcanza el objetivo multiusuario (init 3). Para ejecutar los scripts, deben estar ubicados en la carpeta minios/scripts. La variable de el script se puede ejecutar como interactica, segundo plano o falso. De manera predeterminada, cuando se encuentran los scripts en la carpeta especificada, el sistema solo arranca en el destino multiusuario, después de lo cual ejecuta interactivamente los scripts en orden alfabético. Con scripts=background, el sistema arranca como de costumbre, los scripts se ejecutan en segundo plano. Cuando scripts=false, los scripts no se cargan, incluso si se encuentran en la carpeta de scripts. | scripts=interactive |
|  |  | scripts=background |
|  |  | scripts=false |
| cloud | Modo especial para ejecutar como un host de inicio en la nube. | cloud |
| hide\_credentials | Oculte las credenciales que se muestran como un mensaje en la consola al inciar el sistema. | hide\_credentials |
| autologin= | Habilitar/Deshabilitar el inicio de sesión automático. Habilitado por defecto | autologin=true<br>autologin=false |
| changes\_size= | El tamaño máximo del archivo de guardado dinámico. El valor predeterminado es 4000MB para compatibilidad con FAT32. | changes\_size=2000 |
| changes= | El nombre del archivo para guardar los cambios. Changes.dat por defecto. | changes=mychangesfile.img |

Separe los comandos por espacios. Consulte las páginas del manual bootparam para obtener más cheatcodes comunes para todos los Linux.