### Base system

What the hand-built v0.3 image contains and why. Packages built later by pike are in [recipes](../recipes).

### Core

| Package | Purpose |
|---|---|
| Linux kernel | the kernel |
| glibc | C library and the dynamic loader `ld-linux` |
| Bash | shell |
| coreutils | `cat`, `cp`, `rm` and the rest of the basic tools |
| util-linux | `mount`, `agetty` and other system tools |
| ncurses | terminal library, needed by Bash and other terminal programs |

### Libraries

| Package | Purpose |
|---|---|
| OpenSSL | TLS for HTTPS, `libssl` and `libcrypto` |
| zlib | deflate compression, `libz` |
| zstd | `.zst` compression, `libzstd` |
| pcre2 | regular expressions, `libpcre2` |
| elfutils | `libelf` and ELF tools, needed by the kernel build (objtool) |
| libcap | POSIX capabilities, `libcap` |

### Toolchain

| Package | Purpose |
|---|---|
| GCC | C and C++ compiler, with `libstdc++` |
| binutils | assembler `as`, linker `ld` and `objdump`, `strip` and the rest |
| make | runs the builds |
| m4 | macro processor, needed by autoconf and bison |
| autoconf | generates `configure` scripts, needed by git |
| bison | parser generator, needed by the kernel |
| flex | lexer generator, needed by the kernel |
| bc | calculator, needed by the kernel |
| Texinfo | documentation tools, needed to build bc |
| Perl | needed by many builds, including curl and OpenSSL |

### Text and files

| Package | Purpose |
|---|---|
| sed | stream editor |
| grep | searches text |
| awk | text processing, needed by Perl |
| diffutils | `diff` and `cmp` |
| findutils | `find` and `xargs` |
| tar | packs and unpacks archives |
| gzip | `.gz` compression |
| bzip2 | `.bz2` compression |
| xz | `.xz` compression, used by pike packages |

### Network

| Package | Purpose |
|---|---|
| iproute2 | `ip`, sets up the network |
| curl | downloads over HTTP and HTTPS, used by pike |
| wget | downloads over HTTP and HTTPS |
| git | clones repositories, such as this one |
| dnsmasq | small DNS and DHCP server, started by the v0.3 init but not needed |

### Debugging

| Package | Purpose |
|---|---|
| strace | traces system calls |
