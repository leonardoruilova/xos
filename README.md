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

##Requirements
* A Pentium CPU with SSE2, or better.
* VESA 2.0-compatible BIOS, capable of true-color.
* Little over 32 MB of RAM.
* Few megabytes of disk space.

For building requirements, you'll need [Flat Assembler](http://flatassembler.net) in your `$PATH`. Then, run `make` and it will build xOS. Feel free to tweak with xOS as you like, just please give me feedback. To clean up the working directory afterwards, run `make clean`.

##Testing xOS
xOS is provided as a disk image. `disk.hdd` in this repository can be considered the latest nightly build. It is very likely unstable and may crash. Old demo releases are in the "releases" tab. `disk.hdd` is a prebuilt hard disk image that can be used with QEMU or VirtualBox, though it performs best on VirtualBox. If you're tweaking the source and want to build xOS, simply run `make` as said above. To run xOS under QEMU, then `make run`. The Makefile assumes FASM and QEMU are both in your `$PATH`.  
If you want to test xOS on real hardware without dumping the hard disk, use [SYSLINUX MEMDISK](http://www.syslinux.org/wiki/index.php?title=Download) and GRUB or another bootloader to boot xOS from a USB stick, or a hard disk. Use `disk.hdd` as the INITRD of MEMDISK. Any changes made within xOS will then be removed after system reset. xOS has been tested with SYSLINUX 4.07, but should work with other versions too.

##Contact
I can be contacted at omarx024@gmail.com. I am also user **omarrx024** on the OSDev Forum.

##Spanish translation
Esta traduccion ha sido liberada a los Comunes por Virgilio Leonardo Ruilova, bajo la licencia Creative Commons CC-BY-NC-SA.
