# pike

Small source-based package manager written in Bash, in the spirit of CRUX pkgutils and KISS. It uses only what is already in the image: bash, tar, xz, sha256sum and curl.

### Install

pike is part of the base system. It goes into the image root with:

```
make -C pike DESTDIR=/mnt/rawlinux install
```

This puts `pike` in `/usr/bin` and recipes in `/usr/share/pike/recipes`.

### Usage

```
pike adopt
pike add less
pike list
pike owns /bin/less
pike files less
pike remove less
```

`adopt` records every file that no package owns as the `base-system` package, so `owns` works for the hand-built system too. Run it again to pick up new files. `add` builds and installs a package with its dependencies. `build`, `install`, `deps` and `checksum` do single steps, see `pike help`.

### Recipes

`recipes/<name>/recipe`:

```bash
name=less
version=679
release=1
depends=()
source=("https://www.greenwoodsoftware.com/less/less-$version.tar.gz")
sha256=(9b68820c34fa8a0af6b0e01b74f0298bcdd40a0489c61649b47058908a153d78)

build() {
	cd "less-$version"
	./configure --prefix=/usr --sysconfdir=/etc
	make
	make DESTDIR="$PKG" install
}
```

`build()` runs in `$SRC` with the sources unpacked and installs into `$PKG`. `pike checksum <name>` prints the `sha256` array for a new recipe.

Config files go to `backup=(etc/foo.conf)`. On upgrade, a locally changed file is kept and the new one lands next to it as `.new`. On remove, a changed file is saved as `.pikesave`.

### How it works

- built packages: `/var/cache/pike/packages/<name>#<version>-<release>.tar.xz`
- database: `/var/lib/pike/db/<name>/{version,depends,backup,manifest,takeover}`, plain text
- install refuses files owned by another package and untracked files already on disk
- files of `base-system` are taken over by the package; the originals are kept in `/var/lib/pike/base` and come back when the package is removed or stops shipping them
- `adopt` skips `/home`, `/root`, `/tmp`, `/var/tmp`, `/var/cache` and other filesystems; `base-system` cannot be removed
- upgrade removes files the new version no longer ships
- `/bin`, `/sbin`, `/lib` and `/lib64` are symlinks to `/usr`, so packages install into `/usr`
- `ROOT=/mnt/target pike install less` installs into another root

### Tests

`make check` in `pike/` runs shellcheck and `tests/run.sh`.

### Limitations

- no signatures, sources are checked only against sha256 from the recipe
- upgrade is not atomic
- `build()` runs as root, without a sandbox
- files created after `pike adopt` are untracked until it runs again, so a package shipping one conflicts with it
