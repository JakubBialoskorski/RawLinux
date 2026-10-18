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

After changing the config, update its sum in the recipe with `pike checksum linux`.
