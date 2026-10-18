# Users and login

agetty on `tty1` and `ttyS0` shows `/etc/issue` and asks for a login name. `login` checks the password against `/etc/shadow`, gives the terminal to the user, switches to the user and starts a login shell, which reads `/etc/profile`.

### Install

```
pike add shadow
pike build base-files
pike install base-files
passwd root
```

| Package | What for |
|---|---|
| `libxcrypt` | `crypt()`, which glibc 2.41 does not have |
| `shadow` | `login`, `su`, `passwd`, `useradd`, `usermod`, `groupadd` and the other tools for users and groups |
| `base-files` | `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow`, `/etc/shells`, `/etc/issue` and the login prompts in `/etc/inittab` |

`base-files` depends on `shadow`, because its `/etc/inittab` starts `login`. Every password in `base-files` is locked, so set the root password before rebooting, or nobody can log in.

On the v0.3 image, pike keeps the old `/etc/passwd`, which has only root, and puts the new one next to it. The root line is the same, so take the new one. The v0.3 shell has no controlling terminal, so `passwd` cannot ask for the password there, and `chpasswd` sets it instead:

```
mv /etc/passwd.new /etc/passwd
echo 'root:rawlinux' | chpasswd
```

### Users

```
useradd -m user
passwd user
su -
```

`useradd -m` creates `/home/user` and a group of the same name. Passwords are hashed with yescrypt, `$y$` in `/etc/shadow`, which only root can read. `passwd`, `su` and the other tools that change these files are setuid root. System users such as `bin`, `daemon` and `nobody` have no password and `/usr/bin/false` as the shell.

### Limitations

- no PAM and no sudo: root logs in or uses `su`
- the 6.14.0-rc2 kernel from v0.3 has no `MULTIUSER`, so `login` fails on it with `setgid: Function not implemented`; boot it with `init=/bin/bash`
