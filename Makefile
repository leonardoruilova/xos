
all:
	if [ ! -d "out" ]; then mkdir out; fi
	if [ ! -d "out/xfs" ]; then mkdir out/xfs; fi
	dd if=/dev/zero bs=512 count=71568 of=disk.hdd
	fasm kernel/boot/mbr.asm out/mbr.bin
	fasm kernel/boot/boot_hdd.asm out/boot_hdd.bin
	fasm kernel/kernel.asm out/kernel32.sys
	fasm tmp/root.asm out/root.bin
	fasm hello/hello.asm out/hello.exe
	fasm draw/draw.asm out/draw.exe
	fasm buttontest/buttontest.asm out/buttontest.exe
	fasm calc/calc.asm out/calc.exe
	fasm shell/shell.asm out/shell.exe
	dd if=out/mbr.bin conv=notrunc bs=512 count=1 of=disk.hdd
	dd if=out/boot_hdd.bin conv=notrunc bs=512 seek=63 of=disk.hdd
	dd if=out/root.bin conv=notrunc bs=512 seek=64 of=disk.hdd
	dd if=out/kernel32.sys conv=notrunc bs=512 seek=200 of=disk.hdd
	dd if=out/hello.exe conv=notrunc bs=512 seek=4000 of=disk.hdd
	dd if=out/draw.exe conv=notrunc bs=512 seek=4001 of=disk.hdd
	dd if=out/buttontest.exe conv=notrunc bs=512 seek=4002 of=disk.hdd
	dd if=out/calc.exe conv=notrunc bs=512 seek=4010 of=disk.hdd
	dd if=out/shell.exe conv=notrunc bs=512 seek=4020 of=disk.hdd
	dd if=wp/wp6.bmp conv=notrunc bs=512 seek=1000 of=disk.hdd
	dd if=shell/shell.cfg conv=notrunc bs=512 seek=4040 of=disk.hdd
	gcc -c xfs/src/main.c -o out/xfs/main.o
	gcc -c xfs/src/xfs.c -o out/xfs/xfs.o
	gcc out/xfs/*.o -o ./xfs/xfs

run:
	qemu-system-i386 -hda disk.hdd -m 128 -vga std -serial stdio -usb

runsata:
	qemu-system-i386 -m 128 -vga std -serial stdio -device ahci,id=ahci -drive if=none,file=disk.hdd,id=xosdrive -device ide-drive,drive=xosdrive,bus=ahci.0

runusb:
	qemu-system-i386 -m 128 -vga std -serial stdio -usbdevice disk:disk.hdd

clean:
	if [ -d "out/xfs" ]; then rm out/xfs/*; rmdir out/xfs; fi
	if [ -d "out" ]; then rm out/*; rmdir out; fi


