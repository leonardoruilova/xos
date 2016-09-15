#!/bin/sh
mkdir out
fasm kernel/kernel.asm out/kernel32.sys
dd if=out/kernel32.sys conv=notrunc bs=512 seek=200 of=disk.hdd
