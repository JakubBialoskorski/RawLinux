# RawLinux

Barebones Linux custom image, based on 6.18 LTS kernel - smallest possible "distribution".

Everything redistributed in this project can be found in [sources](docs/sources.txt) file.

### How to run it

Grab the latest [release](https://github.com/JakubBialoskorski/RawLinux/releases) .

Unzip `disk.img.7z` file.

Make sure you have `qemu` installed: 
* Ubuntu / Mint: `sudo apt install qemu-system-x86`
* Arch: `sudo pacman -S qemu-full`

`disk.img` is a qcow2 image, 100 GiB virtual size, of which only the used part takes space. Launch it with:

```
qemu-system-x86_64 -m 2G -drive file=disk.img,format=qcow2
```

On Linux, add `-enable-kvm -smp 4` to run it at hardware speed, which needs access to `/dev/kvm`. Add `-nographic` to log in on the serial console in the terminal instead.

RawLinux boots from IDE, SATA (AHCI), NVMe and virtio disks and gets its network address with DHCP, so faster paravirtual devices work too:

```
qemu-system-x86_64 -enable-kvm -smp 4 -m 2G -drive file=disk.img,format=qcow2,if=virtio -nic user,model=virtio-net-pci
```

Log in as `root` with password `rawlinux` and change it with `passwd`.

### Package manager

RawLinux builds its own packages with [pike](docs/package-manager.md), from the recipes in `/usr/share/pike/recipes`:

```
pike add less
```

`pike upgrade` rebuilds what changed in the recipes. To move v0.4 to v0.5, see [package manager](docs/package-manager.md#install).

### Documentation

* [boot process](docs/boot-process.md)
* [kernel](docs/kernel.md)
* [users and login](docs/users.md)
* [init system decision](docs/decisions/0001-init-system.md)
* [base system](docs/libs-purpose.md)

### Roadmap & delivery

[x] get rid of Busybox

[x] add proper shell

[x] add Coreutils, Util-Linux, glibc, ncurses

[x] enable non-static libraries

[x] add file editor (nano)

[x] enable networking (ethernet)

[x] add compiler (self-sustained system)

[x] document system libs and their purpose

[x] add package manager (pike)

[x] build the kernel inside RawLinux (6.18 LTS)

[x] add init system (OpenRC)

[x] add users and login

[x] get the network address with DHCP

[x] boot from SATA, NVMe and virtio disks

[ ] add default graphical environment

[ ](somewhere in the future) publish a live boot USB
