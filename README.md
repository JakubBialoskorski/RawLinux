# RawLinux

Barebones Linux custom image, based on 6.14.0-rc3 kernel - smallest possible "distribution". Uses official [torvalds/linux](https://github.com/torvalds/linux) .

### How to run it

Unzip `disk.img.7z` file.

Make sure you have `qemu` installed: 
* Ubuntu / Mint: `sudo apt install qemu-system-x86`
* Arch: `sudo pacman -S qemu-full`

Launch it with `qemu-system-x86_64 disk.img` .

### Roadmap

[x] get rid of Busybox

[x] add proper shell

[x] add Coreutils, Util-Linux, glibc, ncurses

[ ] enable non-static libraries

[ ] enable networking (proper init)

[ ] configure systemd

[ ](somewhere in the future) publish a live boot USB
