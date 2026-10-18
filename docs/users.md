# Users and login

agetty on `tty1` and `ttyS0` shows `/etc/issue` and asks for a login name. `login` checks the password against `/etc/shadow`, gives the terminal to the user, switches to the user and starts a login shell, which reads `/etc/profile`.

### Packages

| Package | What for |
|---|---|
| `libxcrypt` | `crypt()`, which glibc 2.41 does not have |
| `shadow` | `login`, `su`, `passwd`, `useradd`, `usermod`, `groupadd` and the other tools for users and groups |
| `base-files` | `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow`, `/etc/shells`, `/etc/issue` and the login prompts in `/etc/inittab` |

`base-files` depends on `shadow`, because its `/etc/inittab` starts `login`. Every password in `base-files` is locked, the image sets the root password, see [README](../README.md).

### Users

```
useradd -m user
passwd user
su -
```

`useradd -m` creates `/home/user` and a group of the same name. Passwords are hashed with yescrypt, `$y$` in `/etc/shadow`, which only root can read. `passwd`, `su` and the other tools that change these files are setuid root. System users such as `bin`, `daemon` and `nobody` have no password and `/usr/bin/false` as the shell.

### Limitations

- no PAM and no sudo: root logs in or uses `su`
