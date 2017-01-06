#!/bin/sh
mkdir out
#iasl kernel/acpi/test.asl
fasm kernel/kernel.asm out/kernel32.sys
fasm tmp/root.asm
fasm hello/hello.asm out/hello.exe
fasm draw/draw.asm out/draw.exe
dd if=tmp/root.bin conv=notrunc bs=512 seek=64 of=disk.hdd
dd if=out/kernel32.sys conv=notrunc bs=512 seek=200 of=disk.hdd
dd if=out/hello.exe conv=notrunc bs=512 seek=4000 of=disk.hdd
dd if=out/draw.exe conv=notrunc bs=512 seek=4001 of=disk.hdd
dd if=wp/wp5.bmp conv=notrunc bs=512 seek=1000 of=disk.hdd

