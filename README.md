# RawLinux

Barebones Linux custom image, based on 6.14.0-rc2 kernel - smallest possible "distribution".

Everything redistributed in this project can be found in [sources](docs/sources.txt) file.

### How to run it

Grab the latest [release](https://github.com/JakubBialoskorski/RawLinux/releases) .

Unzip `disk.img.7z` file.

Make sure you have `qemu` installed: 
* Ubuntu / Mint: `sudo apt install qemu-system-x86`
* Arch: `sudo pacman -S qemu-full`

Launch it with `qemu-system-x86_64 disk.img` .

### Roadmap & delivery

[x] get rid of Busybox

[x] add proper shell

[x] add Coreutils, Util-Linux, glibc, ncurses

[x] enable non-static libraries

[x] add file editor (nano)

[x] enable networking (ethernet)

[x] add compiler (self-sustained system)

[x] document system libs and their purpose

[ ] configure systemd (or openrc, not decided yet)

[ ] add default graphical environment

[ ](somewhere in the future) publish a live boot USB
