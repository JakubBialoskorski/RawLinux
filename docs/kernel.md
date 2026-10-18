# Kernel

Linux 6.18 LTS, built inside RawLinux with [pike](package-manager.md). Everything is built in, there are no modules and no initramfs.

### Build

```
pike add linux
```

This installs `/boot/bzImage` and `/boot/.config`, taking them over from `base-system`. `pike remove linux` puts the previous kernel back.

The build uses all CPUs with `make -j$(nproc)`. The 6.14.0-rc2 kernel from v0.3 has no SMP, so on it the first build runs on one CPU. Once booted into 6.18, RawLinux sees all of them.

### Config

`recipes/linux/config` is the v0.3 config moved to 6.18 with `make olddefconfig`, with these options turned on:

| Option | Why |
|---|---|
| `SMP`, `NR_CPUS=64` | more than one CPU |
| `ACPI` | CPU discovery and power off |
| `MULTIUSER` | users, `setuid` |
| `FILE_LOCKING` | `flock` |
| `SHMEM`, `TMPFS` | mounting `tmpfs` |
| `EVENTFD` | curl resolving host names |
| `EPOLL`, `SIGNALFD`, `TIMERFD` | daemons |
| `FHANDLE`, `SYSVIPC`, `POSIX_MQUEUE`, `AIO` | common userland |
| `CGROUPS` | `/sys/fs/cgroup`, mounted by OpenRC |
| `RTC_CLASS`, `RTC_DRV_CMOS` | system clock from the RTC |
| `MAGIC_SYSRQ` | emergency sync, remount read-only and reboot |
| `SATA_AHCI`, `BLK_DEV_NVME` | SATA and NVMe disks, as on VirtualBox and real hardware |
| `VIRTIO_PCI`, `VIRTIO_BLK`, `SCSI_VIRTIO`, `VIRTIO_NET`, `VIRTIO_CONSOLE`, `HW_RANDOM_VIRTIO` | paravirtual disks, network, console and entropy |
| `E1000E` | Intel network cards newer than the e1000 ones |
| `PCI_MSI` | message signalled interrupts, for virtio and NVMe |

Without an initramfs, the kernel finds the root file system itself, so GRUB names it by the partition: `root=PARTUUID=a549ab39-01`. It stays the same whether the disk shows up as `sda`, `vda` or `nvme0n1`.

After changing the config, update its sum in the recipe with `pike checksum linux`.

### Fallback

The previous kernel, 6.18.57 release 2 from v0.4, stays as `/boot/bzImage-6.18.57-2`, with the GRUB entry `RawLinux 6.18.57-2 (fallback)`. It boots the full system, but has none of the drivers above, so only from an IDE disk, the QEMU default.

To get a root shell without a password, edit an entry in GRUB with `e` and replace `ro` on the `linux` line with `rw init=/bin/bash`. There is no init to shut down, so leave it with the commands below. `mount` finds `/` by its `PARTUUID` in `/etc/fstab`, which needs `/proc` and `/sys`:

```
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -o remount,ro / && reboot -f
```
