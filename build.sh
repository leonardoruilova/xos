#!/bin/sh
mkdir out
iasl kernel/acpi/test.asl
fasm kernel/kernel.asm out/kernel32.sys
fasm tmp/root.asm
dd if=tmp/root.bin conv=notrunc bs=512 seek=64 of=disk.hdd
dd if=out/kernel32.sys conv=notrunc bs=512 seek=200 of=disk.hdd
dd if=wp/wp3.bmp conv=notrunc bs=512 seek=1000 of=disk.hdd

