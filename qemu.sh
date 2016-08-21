#!/bin/sh
qemu-system-i386 -drive file=disk.hdd,if=none,id=disk -device ahci,id=ahci -device ide-drive,drive=disk,bus=ahci.0 -serial stdio

