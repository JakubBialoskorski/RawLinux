# 0001: Init system

Status: accepted

### Context

Up to v0.3, `/sbin/init` was a Bash script. It mounted `/proc` and `/sys`, set up `eth0` and ran `exec /bin/bash`. There was no shutdown at all: the file system was never unmounted, so the next boot had to recover the ext4 journal.

The init system has to be built inside RawLinux, with what is there: gcc, make, Bash and Perl. There is no Python, no meson and no ninja.

### Options

| | Builds with | Needs |
|---|---|---|
| systemd | meson, ninja | Python with Jinja2, udev, a kernel with many more options |
| OpenRC on sysvinit | meson, ninja | Python |
| sysvinit + LFS boot scripts | make | nothing new |

### Decision

OpenRC 0.64 started by sysvinit 3.14, as Gentoo does it. Python, ninja and meson are packaged with pike first.

### Consequences

- Services are shell scripts with declared dependencies (`need`, `use`, `after`), OpenRC orders them. `rc-status`, `rc-service` and `rc-update` manage them.
- sysvinit stays process 1, runlevels come from `/etc/inittab`. OpenRC also has its own `openrc-init`, unused for now.
- No supervision of services beyond `respawn` in `/etc/inittab`, until `supervise-daemon` is used.
- The LFS boot scripts were the smaller step, but LFS 12.4 is the last release with them, LFS 13 is systemd only. OpenRC is maintained upstream.
- Python, meson and ninja are now part of the system, which also opens the way for other meson projects.
