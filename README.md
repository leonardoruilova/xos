![](https://s28.postimg.org/kgj29w77x/main_interface.png)
![](https://s23.postimg.org/j38d5uf2z/collage.jpg)
El Sistema Operativo xOS fue programado para CPU de 32-bit y usa interfaz grafica. Fue programado completamente en lenguaje de bajo nivel para PC. 

El uso de lenguaje de bajo nivel otorga mayor velocidad, menor consumo de memoria y una simplicidad generalizada. 

La meta de este proyecto es concebir un Sistema Operativo funcional, diminuto y sencillo.


##Cualidades
El codigo del Sistema Operativo xOS se encuentra en etapas tempranas de desarrollo, sin embargo hemos logrado las siguientes funcionalidades:
* Gestion de energia mediante PCI y ACPI, con apagado.
* Disponibilidad de discos duros ATA y Serial ATA.
* Multitarea 
* Software en espacio de usuario.
* Uso de teclados y mouse PS/2.
* Interfaz grafica en color verdadero mediante ventanas.

##Requisitos
* Un CPU Pentium con SSE2, cuanto menos.
* Una BIOS de estandares VESA 2.0 o compatibles, con Color Verdadero.
* Una memoria RAM de 32 MB.
* Pocos megabytes de espacio en su disco duro.

Para compilar el codigo fuente de xOS sera necesario utilizar el [Flat Assembler](http://flatassembler.net) en su `$PATH`. 
Posteriormente, ejecute `make` para compilar el codigo fuente de xOS. 

Sientase con todo el derecho de personalizar xOS a su gusto, tan solo entregueme retroalimentacion. 

Para limpiar el working directory afterwards, ejecute `make clean`.

##Pruebas de xOS
Ud. podra usar xOS como imagen de disco. El archivo`disk.hdd`en este repositorio puede ser considerado la ultima nightly build. Sin duda sera inestable y podria fallar. 

Es posible usar versiones de demostracion antigua en la pestana "releases". 

El archivo `disk.hdd` consite en una imagen de disco previamente compilada, lista para ser su uso mediante QEMU o VirtualBox, si bien el mejor rendimiento se da en VirtualBox. 

En caso que ud. este personalizando el codigo fuente y desee compilar el codigo de xOS, tan solo ejecute `make` como hemos mencionado anteriormente. 

Para ejecutar xOS virtualizado bajo QEMU, ejecute `make run`. El archivo de compilacion Makefile asumes que tanto FASM como QEMU se encuntran en `$PATH`.  

Si ud desea probar xOS en un computador without dumping the hard disk, use [SYSLINUX MEMDISK](http://www.syslinux.org/wiki/index.php?title=Download) y GRUB u otro bootloader para iniciar xOS desde una memoria USB o desde un disco duro. 

Por favor, utilice el archivo `disk.hdd` como el INITRD de MEMDISK. 

Todos los cambios realizados dentro de xOS seran deshechos una vez reinicie el sistema. 

El Sistema Operativo xOS ha sido probado con SYSLINUX 4.07, pero debiera funcionar con otras versiones.

##Contact
El autor puede ser contactado en el correo omarx024@gmail.com. 
En el foro OSDev, el autor usa la cuenta **omarrx024**.

##Spanish translation
Esta traduccion ha sido liberada a los Comunes por Virgilio Leonardo Ruilova, bajo la licencia Creative Commons CC-BY-NC-SA.
