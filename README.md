# RawLinux

Barebones Linux custom image, based on 6.13.0 kernel - smallest possible "distribution". Uses official [torvalds/linux](https://github.com/torvalds/linux) and [Busybox](https://git.busybox.net/busybox).

### How to run it

Make sure you have `qemu` installed: `sudo apt install qemu-system-x86` .

Launch it with `qemu-system-x86_64 disk.img` .

### Roadmap

* get rid of Busybox
* enable non-static libraries
* add proper shell
* add Coreutils, Util-Linux, glibc, ncurses
* enable networking (proper init)
* configure systemd
* (somewhere in the future) publish a live boot USB
