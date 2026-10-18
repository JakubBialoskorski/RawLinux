# Boot process

From power on to the login prompt, and back to power off.

1. **GRUB.** The BIOS loads GRUB from the MBR. GRUB reads `/boot/grub/grub.cfg` and starts `/boot/bzImage` with `root=/dev/sda1 ro`.
2. **Kernel.** All drivers are built in, so there is no initramfs. The kernel mounts the root file system read-only, mounts `devtmpfs` on `/dev` and starts `/sbin/init` as process 1. See [kernel](kernel.md).
3. **init.** sysvinit reads `/etc/inittab` and runs OpenRC: `openrc sysinit`, `openrc boot`, then `openrc default` for runlevel 3.
4. **OpenRC.** A runlevel is a directory of links in `/etc/runlevels`. OpenRC starts the services in the order of their dependencies:

| Runlevel | What its services do |
|---|---|
| `sysinit` | mount `/proc`, `/run`, `/sys`, `/sys/fs/cgroup`, `/dev/pts` and `/dev/shm`, link `/dev/fd` to `/proc/self/fd` |
| `boot` | check `/` with `fsck`, remount it read-write, mount the rest of `/etc/fstab`, set the host name and the clock, bring up `lo` and `eth0` |
| `default` | run `/etc/local.d` scripts |

5. **Login.** init starts `agetty` on `tty1` and on the serial port `ttyS0`. agetty asks for a login name, `login` checks the password and starts a login shell, which reads `/etc/profile`. See [users and login](users.md).

`rc-status` shows the services, `rc-service <name> restart` restarts one, `rc-update add <name> default` adds one to a runlevel.

### Shutdown

`poweroff` and `reboot` switch to runlevel 0 and 6. init runs `openrc shutdown` or `openrc reboot`: the services stop, every process gets `TERM` and then `KILL`, and `/` is remounted read-only. Then the kernel powers off through ACPI, or reboots.

### Packages

```
pike add openrc
```

This builds and installs, in order:

| Package | What for |
|---|---|
| `libxcrypt` | `crypt()`, for shadow |
| `pkgconf` | `pkg-config`, for shadow, e2fsprogs and OpenRC |
| `shadow` | `login`, see [users and login](users.md) |
| `base-files` | `/etc/inittab`, `/etc/fstab`, users and groups, host name, network address, `/etc/profile` |
| `util-linux` | headers and `.pc` files for libblkid and libuuid, `fsck`, `mount`, `agetty` |
| `e2fsprogs` | `fsck.ext4` |
| `inetutils` | `hostname` and `ping` |
| `python`, `ninja`, `meson` | building OpenRC |
| `sysvinit` | `init`, `shutdown`, `halt`, `poweroff`, `reboot` |
| `openrc` | the services and `openrc`, `rc-status`, `rc-service`, `rc-update` |

sysvinit takes `/sbin/init` over from `base-system`. util-linux takes over the hand-built util-linux 2.40, which came without headers and `.pc` files, so e2fsprogs could not be built against libblkid and libuuid. This replaces `mount`, `fsck` and `agetty`, which the boot depends on. Why OpenRC: [ADR 0001](decisions/0001-init-system.md).

On the v0.3 image:

- `/etc/passwd` has only root, and pike keeps it. Take the new one and set the root password before rebooting, see [users and login](users.md).
- `grub.cfg` starts the kernel with `rw`. Then `/` is already writable at boot and OpenRC skips its check, so `rw` has to become `ro`.
- gcc's fixed headers were made from glibc 2.40 headers, and with glibc 2.41 Python does not link. Run gcc's `mkheaders` before `pike add openrc`:

```
/usr/libexec/gcc/x86_64-pc-linux-gnu/14.2.0/install-tools/mkheaders
```
