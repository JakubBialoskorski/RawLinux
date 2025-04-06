Linux Kernel: obviously, we need it.
Bash: to have a basic shell.
coreutils: to be able to run `cat`, `rm`, `cp` etc.
util-Linux: bunch of tools like `mount` .
glibc: contains lib loader `ld-linux`, allows to use dynamic libraries.
Ncurses: allows Bash to work (well, not only it).
iproute2: default network tool, allows connection to the Internet.
elfutils: provides `libelf` and elf editing tools.
libcap: handles priviledge and permissions.
zlib: compression tool, provides `libz`.
zstd: compression lib, handles `.zst`, `.gz`, `.xz`, `.lz4` formats. Provides `libzstd`.
wget: tool for downloading stuff.
pcre2: tool for regex pattern matching.
OpenSSL: library for SSL, TLS, HTTPS etc.
DNSMasq: small DNS server from more civilized times (before systemd).
GCC & libstddc++: basic GNU compiler and it's C++ libs.
make: tool to build from sources.
tar: to pack / unpack files.
gzip: to complement tar with it's functionalities.
sed: stream editor.
grep: to catch strings.
awk: dependency for Perl.
binutils: used with `make`.
xz: to test compiler inside the distro.
diffutils: provides `diff` and `cmp`.
m4: needed by `autoconf`.
bison: needed by the kernel and other GNU software.
bzip2: to complement `tar` and `gzip`.
FLEX: Fast Lexical Analyzer, needed by the kernel.
findutils: provides `find`.
Perl: needed everywhere + `curl`.
autoconf: needed by `git`.
Texinfo: required by `bc`, which is a dependency for the kernel.
BC: needed to compile the kernel itself.
curl: tool for downloading stuff.
git: to clone stuff, mostly new kernels.
strace: to better debug what's wrong from inside the distro.
