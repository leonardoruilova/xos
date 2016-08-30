#!/bin/sh
gcc -c src/main.c -o src/main.o
gcc -c src/xfs.c -o src/xfs.o
gcc src/*.o -o xfs

