![xOS User Interface](https://s30.postimg.org/hhwwn5kwh/xos.png)  
xOS is an operating system written for the PC entirely in assembly language. This results in faster execution, smaller program sizes and overall simplicity. The goal of xOS is to be fully functional, yet small and simple.  
#Features
xOS is still under early stages of development; although the following features are already implemented:
* PCI and ACPI, with shutdown.
* ATA and SATA hard disks.
* Multitasking and userspace.
* PS/2 keyboard and mouse.
* True-color windowed graphical user interface.

#Requirements
* A Pentium CPU with SSE2, or better.
* VESA 2.0-compatible BIOS, capable of true-color.
* Little over 16 MB of RAM.
* Few megabytes disk space.

For building requirements, you'll need [Flat Assembler](http://flatassembler.net) in your `$PATH`. Then, run `build.sh` and it will build the xOS kernel to `disk.hdd`. Feel free to tweak with xOS as you like, just please give me feedback.

#Testing xOS
xOS is provided as a disk image. `disk.hdd` in this repository can be considered the latest nightly build. It is very likely unstable and may crash. Releases are under the release tab, or on the site. This disk image can be used on Bochs, QEMU and VirtualBox. On Bochs, the CHS values are 71/16/63. For now, xOS only supports ATA and SATA hard disks, and SATA support is somewhat incomplete, and so on VirtualBox, use IDE instead of SATA.  
To test xOS under QEMU, simply run `qemu-system-i386 -hda disk.hdd`.

#Contact
I can be contacted at omarx024@gmail.com. I am also user **omarrx024** on the OSDev Forum.

